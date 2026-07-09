defmodule Localize.Lua.API do
  @moduledoc """
  The `Lua.API` installed into a Luerl VM under the `localize` scope.

  Every function is callable from Lua as `localize.<name>(...)` once the module
  is installed with `Localize.Lua.install/1`. The functions are thin, total
  wrappers over `Localize`: each accepts primitive Lua values plus an optional
  options table, and always returns a string. On any error — an unknown locale,
  an unparseable date, a malformed options table — the function falls back to a
  safe rendering of its input rather than raising, so a template can never crash
  the host render path.

  See `Localize.Lua` for the installation entry point and worked examples.

  """

  use Lua.API, scope: "localize"

  alias Localize.DateTime.Relative
  alias Localize.Language
  alias Localize.Lua.Options
  alias Localize.Message
  alias Localize.Number
  alias Localize.Territory
  alias Localize.Unit

  # `Localize.Date`, `Localize.Time`, `Localize.DateTime` and `Localize.List` are
  # intentionally left fully qualified — aliasing them would shadow the Elixir
  # built-ins of the same name (see `.credo.exs` `excluded_lastnames`).

  @time_units ~w(second minute hour day week month quarter year)a
  @time_unit_lookup Map.new(@time_units, &{Atom.to_string(&1), &1})

  @doc """
  Formats a number for the active locale (`localize.number(1234.5, {locale = "de"})`).

  Pass `format = "percent"` for percentages or `currency = "USD"` for currency;
  any option accepted by `Number.to_string/2` may appear in the table.
  """
  deflua number(value, options \\ []), state do
    result = Number.to_string(value, decode_options(state, options))
    unwrap(result, value)
  end

  @doc """
  Formats a number as a currency amount (`localize.currency(1234.56, "EUR", {locale = "de"})`).
  """
  deflua currency(value, currency_code, options \\ []), state do
    options = decode_options(state, options) |> Keyword.put(:currency, to_string(currency_code))
    unwrap(Number.to_string(value, options), value)
  end

  @doc """
  Formats a fractional number as a percentage (`localize.percent(0.56)` → `"56%"`).
  """
  deflua percent(value, options \\ []), state do
    options = decode_options(state, options) |> Keyword.put_new(:format, :percent)
    unwrap(Number.to_string(value, options), value)
  end

  @doc """
  Formats an ISO 8601 date string (`localize.date("2025-07-10", {locale = "de", format = "long"})`).
  """
  deflua date(iso_string, options \\ []), state do
    with {:ok, date} <- Date.from_iso8601(to_string(iso_string)),
         {:ok, formatted} <- Localize.Date.to_string(date, decode_options(state, options)) do
      formatted
    else
      _error -> to_string(iso_string)
    end
  end

  @doc """
  Formats an ISO 8601 time string (`localize.time("14:30:00", {locale = "en"})`).
  """
  deflua time(iso_string, options \\ []), state do
    with {:ok, time} <- Time.from_iso8601(to_string(iso_string)),
         {:ok, formatted} <- Localize.Time.to_string(time, decode_options(state, options)) do
      formatted
    else
      _error -> to_string(iso_string)
    end
  end

  @doc """
  Formats an ISO 8601 datetime string (`localize.datetime("2025-07-10T14:30:00Z", {locale = "fr"})`).
  """
  deflua datetime(iso_string, options \\ []), state do
    with {:ok, datetime} <- parse_datetime(to_string(iso_string)),
         {:ok, formatted} <- Localize.DateTime.to_string(datetime, decode_options(state, options)) do
      formatted
    else
      _error -> to_string(iso_string)
    end
  end

  @doc """
  Formats a relative time (`localize.relative(-3, "day")` → `"3 days ago"`).

  The unit is one of `second`, `minute`, `hour`, `day`, `week`, `month`,
  `quarter`, or `year`.
  """
  deflua relative(value, unit, options \\ []), state do
    options = relative_options(decode_options(state, options), unit)
    unwrap(Relative.to_string(value, options), value)
  end

  @doc """
  Formats a measurement (`localize.unit(42, "kilometer", {format = "short"})` → `"42 km"`).
  """
  deflua unit(value, unit_name, options \\ []), state do
    with {:ok, measurement} <- Unit.new(value, to_string(unit_name)),
         {:ok, formatted} <- Unit.to_string(measurement, decode_options(state, options)) do
      formatted
    else
      _error -> "#{value} #{unit_name}"
    end
  end

  @doc """
  Joins a Lua array into a locale-aware list (`localize.list({"a", "b", "c"})` → `"a, b, and c"`).
  """
  deflua list(items, options \\ []), state do
    items = decode_list(state, items)
    unwrap(Localize.List.to_string(items, decode_options(state, options)), Enum.join(items, ", "))
  end

  @doc """
  Formats a MessageFormat 2 message with bindings, including CLDR plurals.

      localize.message(
        ".input {$count :integer}\\n.match $count\\n one {{{$count} item}}\\n * {{{$count} items}}",
        {count = 3}
      )
      -- "3 items"
  """
  deflua message(text, bindings \\ []), state do
    unwrap(Message.format(to_string(text), decode_bindings(state, bindings)), text)
  end

  @doc """
  Localized display name of a territory (`localize.territory_name("AU", {locale = "fr"})`).
  """
  deflua territory_name(code, options \\ []), state do
    display_name(&Territory.display_name/2, code, &String.upcase/1, state, options)
  end

  @doc """
  Localized display name of a language (`localize.language_name("de", {locale = "en"})` → `"German"`).
  """
  deflua language_name(code, options \\ []), state do
    display_name(&Language.display_name/2, code, &String.downcase/1, state, options)
  end

  # --- helpers -------------------------------------------------------------

  defp decode_options(_state, options) when options in [[], nil], do: []
  defp decode_options(state, options), do: state |> Lua.decode!(options) |> Options.normalize()

  defp decode_list(_state, items) when items in [[], nil], do: []

  defp decode_list(state, items) do
    case Lua.decode!(state, items) do
      list when is_list(list) -> to_value_list(list)
      other -> [decoded_value(other)]
    end
  end

  # Luerl decodes a sequence table (`{"a", "b"}`) as index-keyed pairs
  # (`[{1, "a"}, {2, "b"}]`); recover the values in index order. A non-sequence
  # list is mapped element-wise.
  defp to_value_list([{index, _value} | _rest] = pairs) when is_integer(index) do
    pairs
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&decoded_value(elem(&1, 1)))
  end

  defp to_value_list(list), do: Enum.map(list, &decoded_value/1)

  defp decode_bindings(_state, bindings) when bindings in [[], nil], do: %{}

  defp decode_bindings(state, bindings) do
    case Lua.decode!(state, bindings) do
      pairs when is_list(pairs) ->
        Map.new(pairs, fn {key, value} -> {to_string(key), decoded_value(value)} end)

      _other ->
        %{}
    end
  end

  # Luerl hands whole numbers back as floats; collapse them to integers so
  # `:integer`-typed MF2 selectors and list items read naturally.
  defp decoded_value(value) when is_float(value) and value == trunc(value), do: trunc(value)
  defp decoded_value(value), do: value

  defp relative_options(options, unit) do
    case Map.get(@time_unit_lookup, to_string(unit)) do
      nil -> options
      resolved -> Keyword.put(options, :unit, resolved)
    end
  end

  defp parse_datetime(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _reason} -> NaiveDateTime.from_iso8601(iso_string)
    end
  end

  defp display_name(fun, code, normalize_case, state, options) do
    string = code |> to_string() |> normalize_case.()

    with {:ok, atom} <- existing_atom(string),
         {:ok, name} <- fun.(atom, decode_options(state, options)) do
      name
    else
      _error -> to_string(code)
    end
  end

  defp existing_atom(""), do: :error

  defp existing_atom(string) do
    {:ok, String.to_existing_atom(string)}
  rescue
    ArgumentError -> :error
  end

  defp unwrap({:ok, value}, _fallback), do: value
  defp unwrap({:error, _reason}, fallback), do: to_string(fallback)
end
