defmodule Localize.Lua.OptionsTest do
  use ExUnit.Case, async: true

  alias Localize.Lua.Options

  describe "normalize/1" do
    test "maps known string keys to Localize option atoms" do
      assert Options.normalize([{"locale", "de"}, {"number_system", "latn"}]) ==
               [locale: "de", number_system: "latn"]
    end

    test "upcases currency codes" do
      assert Options.normalize([{"currency", "usd"}]) == [currency: "USD"]
    end

    test "resolves known format values to atoms" do
      assert Options.normalize([{"format", "percent"}]) == [format: :percent]
    end

    test "passes unknown format values through as strings for custom patterns" do
      assert Options.normalize([{"format", "#,##0.00"}]) == [format: "#,##0.00"]
    end

    test "coerces fractional_digits to an integer" do
      assert Options.normalize([{"fractional_digits", 2.0}]) == [fractional_digits: 2]
    end

    test "drops unknown keys" do
      assert Options.normalize([{"locale", "en"}, {"danger", "rm -rf"}]) == [locale: "en"]
    end

    test "accepts a plain map" do
      assert Options.normalize(%{"locale" => "en"}) == [locale: "en"]
    end

    test "returns an empty list for a non-table value" do
      assert Options.normalize(42) == []
      assert Options.normalize(nil) == []
    end
  end

  describe "atom-table safety (global rule 1)" do
    test "an unknown format value never creates a new atom" do
      unknown = "totally_new_format_#{System.unique_integer([:positive])}"
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end

      # Normalizing it keeps it a string rather than interning a new atom.
      assert Options.normalize([{"format", unknown}]) == [format: unknown]
      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end
    end
  end
end
