defmodule Localize.Lua do
  @moduledoc """
  Locale-aware formatting for the Lua (Luerl) VM, backed by `Localize`.

  `Localize.Lua` installs a small, sandbox-safe `localize` table into a Luerl VM
  so that Lua templates — such as those rendered by `ash_cms` — can format
  numbers, currencies, dates, times, units, lists and MessageFormat 2 messages
  with full CLDR locale awareness. Because Luerl runs entirely on the BEAM, each
  `localize.*` call is an ordinary Elixir function call into `Localize`; nothing
  crosses a native boundary and no unsafe capability is exposed.

  The public surface is deliberately tiny:

    * `install/1` adds the `localize` table to an existing `t:Lua.t/0`.

    * `eval/2` and `eval!/2` are convenience wrappers that install and run a
      script in one call.

  Every installed function returns a string and falls back gracefully on bad
  input, so an untrusted template can never raise on the host render path.

  ### Locale data

  Only the `en` locale ships with `Localize`; other locales are downloaded once
  with `mix localize.download_locales de fr ja`. A `localize.number(1, {locale =
  "de"})` call for a locale that has not been installed formats with the root
  locale rather than raising.

  ### Examples

      iex> {[money], _lua} =
      ...>   Lua.new()
      ...>   |> Localize.Lua.install()
      ...>   |> Lua.eval!(~S[return localize.currency(1234.56, "USD")])
      iex> money
      "$1,234.56"

  """

  alias Localize.Lua.API

  @doc """
  Installs the `localize` API table into a Lua VM.

  ### Arguments

  * `lua` is a `t:Lua.t/0`, usually from `Lua.new/0` or a host-configured VM.

  ### Returns

  * The `t:Lua.t/0` with a `localize` global table whose functions are listed in
    `Localize.Lua.API`.

  ### Examples

      iex> lua = Localize.Lua.install(Lua.new())
      iex> {[list], _lua} = Lua.eval!(lua, ~S[return localize.list({"a", "b", "c"})])
      iex> list
      "a, b, and c"

  """
  @spec install(Lua.t()) :: Lua.t()
  def install(lua) do
    Lua.load_api(lua, API)
  end

  @doc """
  Installs the `localize` API and evaluates a Lua script.

  ### Arguments

  * `script` is the Lua source to evaluate.

  * `lua` is an optional `t:Lua.t/0` to install into; a fresh sandboxed VM is
    used when omitted.

  ### Returns

  * `{:ok, results}` where `results` is the list of decoded Lua return values.

  * `{:error, exception}` if the script raises inside Lua.

  ### Examples

      iex> Localize.Lua.eval(~S[return localize.percent(0.56)])
      {:ok, ["56%"]}

  """
  @spec eval(String.t(), Lua.t()) :: {:ok, [term()]} | {:error, Exception.t()}
  def eval(script, lua \\ Lua.new()) when is_binary(script) do
    {results, _lua} = Lua.eval!(install(lua), script)
    {:ok, results}
  rescue
    exception -> {:error, exception}
  end

  @doc """
  Installs the `localize` API and evaluates a Lua script, returning results or raising.

  ### Arguments

  * `script` is the Lua source to evaluate.

  * `lua` is an optional `t:Lua.t/0` to install into; a fresh sandboxed VM is
    used when omitted.

  ### Returns

  * The list of decoded Lua return values, or raises `Lua.RuntimeException` on a
    Lua error.

  ### Examples

      iex> Localize.Lua.eval!(~S[return localize.unit(42, "kilometer", {format = "short"})])
      ["42 km"]

  """
  @spec eval!(String.t(), Lua.t()) :: [term()]
  def eval!(script, lua \\ Lua.new()) when is_binary(script) do
    {results, _lua} = Lua.eval!(install(lua), script)
    results
  end
end
