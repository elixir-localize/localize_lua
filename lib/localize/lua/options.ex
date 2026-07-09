defmodule Localize.Lua.Options do
  @moduledoc false

  # Converts a decoded Lua options table into a validated Localize keyword list.
  #
  # A Lua call such as `localize.number(1, {currency = "USD", format = "percent"})`
  # arrives here (after `Lua.decode!/2`) as a proplist of string-keyed pairs:
  #
  #     [{"currency", "USD"}, {"format", "percent"}]
  #
  # Only keys in `@key_map` survive; everything else is dropped. Atom-valued
  # options (`:format`, `:style`) are mapped through a compile-time allowlist, so
  # no string sourced from a Lua script is ever passed to `String.to_atom/1` —
  # the atom table cannot be exhausted by a hostile template.

  # Lua option key (string) => Localize option key (atom).
  @key_map %{
    "locale" => :locale,
    "currency" => :currency,
    "format" => :format,
    "style" => :style,
    "fractional_digits" => :fractional_digits,
    "number_system" => :number_system,
    "unit" => :unit
  }

  # Known atom values for `:format` and `:style`. Any value not listed is passed
  # through unchanged as a string — Localize also accepts custom format strings
  # (e.g. "#,##0.00"), and rejects genuinely bad input with an error tuple that
  # the caller turns into a graceful fallback.
  @format_atoms ~w(standard currency accounting percent permille scientific short medium long full none)a
  @style_atoms ~w(short long narrow)a

  @format_lookup Map.new(@format_atoms, &{Atom.to_string(&1), &1})
  @style_lookup Map.new(@style_atoms, &{Atom.to_string(&1), &1})

  @doc """
  Normalizes a decoded Lua options table into a Localize keyword list.

  Accepts the proplist produced by `Lua.decode!/2` for a Lua table, a plain map,
  or `nil`/`[]` (an omitted argument). Unknown keys are dropped and atom-valued
  options are resolved through a static allowlist.
  """
  @spec normalize(term()) :: keyword()
  def normalize(options) when is_map(options) do
    options |> Map.to_list() |> normalize()
  end

  def normalize(options) when is_list(options) do
    options
    |> Enum.flat_map(&normalize_pair/1)
  end

  def normalize(_options), do: []

  defp normalize_pair({key, value}) when is_binary(key) do
    case Map.fetch(@key_map, key) do
      {:ok, option_key} -> [{option_key, coerce(option_key, value)}]
      :error -> []
    end
  end

  defp normalize_pair(_pair), do: []

  defp coerce(:locale, value), do: to_string(value)
  defp coerce(:number_system, value), do: to_string(value)
  defp coerce(:unit, value), do: to_string(value)
  defp coerce(:currency, value), do: value |> to_string() |> String.upcase()
  defp coerce(:format, value), do: atom_or_string(value, @format_lookup)
  defp coerce(:style, value), do: atom_or_string(value, @style_lookup)
  defp coerce(:fractional_digits, value), do: to_integer(value)

  defp atom_or_string(value, lookup) when is_binary(value) do
    Map.get(lookup, value, value)
  end

  defp atom_or_string(value, _lookup) when is_atom(value), do: value
  defp atom_or_string(value, _lookup), do: to_string(value)

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_float(value), do: trunc(value)
  defp to_integer(_value), do: 0
end
