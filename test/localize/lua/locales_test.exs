defmodule Localize.Lua.LocalesTest do
  # Proves locale variance — the whole point of the library. Excluded by default
  # because it needs CLDR data beyond the bundled `en` locale; run with
  # `mix test --include locales`.
  use ExUnit.Case, async: false

  @moduletag :locales

  setup_all do
    Mix.Task.run("localize.download_locales", ~w(de fr))
    :ok
  end

  defp result(script), do: script |> Localize.Lua.eval!() |> hd()

  # CLDR separates the amount and currency sign with a non-breaking space; fold
  # every whitespace kind to a plain space so the assertion reads naturally.
  defp normalize_spaces(string), do: String.replace(string, ~r/\s/u, " ")

  test "German groups thousands with a dot and trails the euro sign" do
    formatted = result(~S[return localize.currency(1234.56, "EUR", {locale = "de"})])
    assert normalize_spaces(formatted) == "1.234,56 €"
  end

  test "German long date reads as German prose" do
    assert result(~S[return localize.date("2025-07-10", {locale = "de", format = "long"})]) ==
             "10. Juli 2025"
  end

  test "French decimal uses a comma" do
    assert result(~S[return localize.number(1234.5, {locale = "fr"})]) =~ "234,5"
  end
end
