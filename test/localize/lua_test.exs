defmodule Localize.LuaTest do
  use ExUnit.Case, async: true

  doctest Localize.Lua

  defp result(script), do: script |> Localize.Lua.eval!() |> hd()

  describe "install/1 and eval!/2" do
    test "installs the localize table into an existing VM" do
      lua = Localize.Lua.install(Lua.new())
      {[value], _lua} = Lua.eval!(lua, ~S[return localize.number(1234.5)])
      assert value == "1,234.5"
    end

    test "eval/2 returns an ok tuple" do
      assert {:ok, ["56%"]} = Localize.Lua.eval(~S[return localize.percent(0.56)])
    end
  end

  describe "number formatting (en)" do
    test "plain number" do
      assert result(~S[return localize.number(1234.5)]) == "1,234.5"
    end

    test "currency via option" do
      assert result(~S[return localize.number(1234.56, {currency = "USD"})]) == "$1,234.56"
    end

    test "currency via dedicated function" do
      assert result(~S[return localize.currency(1234.56, "USD")]) == "$1,234.56"
    end

    test "percent" do
      assert result(~S[return localize.percent(0.56)]) == "56%"
    end
  end

  describe "date and time formatting (en)" do
    test "date" do
      assert result(~S[return localize.date("2025-07-10")]) == "Jul 10, 2025"
    end

    test "datetime accepts a zoned string" do
      assert result(~S[return localize.datetime("2025-07-10T14:30:00Z")]) =~ "2025"
    end

    test "relative time" do
      assert result(~S[return localize.relative(-3, "day")]) == "3 days ago"
    end
  end

  describe "units and lists (en)" do
    test "unit short form" do
      assert result(~S[return localize.unit(42, "kilometer", {format = "short"})]) == "42 km"
    end

    test "list with oxford comma" do
      assert result(~S[return localize.list({"apple", "banana", "cherry"})]) ==
               "apple, banana, and cherry"
    end
  end

  describe "MessageFormat 2 with plurals" do
    @mf2 ~S[return localize.message(".input {$count :integer}\n.match $count\n one {{{$count} item}}\n * {{{$count} items}}", {count = COUNT})]

    test "selects the singular plural category" do
      assert result(String.replace(@mf2, "COUNT", "1")) == "1 item"
    end

    test "selects the plural category" do
      assert result(String.replace(@mf2, "COUNT", "5")) == "5 items"
    end
  end

  describe "display names (en)" do
    test "territory name from a code string" do
      assert result(~S[return localize.territory_name("AU")]) == "Australia"
    end

    test "language name from a code string" do
      assert result(~S[return localize.language_name("de")]) == "German"
    end
  end

  describe "graceful fallbacks (never raises on the render path)" do
    test "unparseable date falls back to the input string" do
      assert result(~S[return localize.date("not-a-date")]) == "not-a-date"
    end

    test "unknown territory code falls back to the input string" do
      assert result(~S[return localize.territory_name("ZZZ")]) == "ZZZ"
    end

    test "unknown locale still returns a string rather than raising" do
      assert is_binary(result(~S[return localize.number(10, {locale = "zz-invalid"})]))
    end

    test "invalid MF2 message falls back to the raw message" do
      assert result(~S[return localize.message("{unclosed")]) == "{unclosed"
    end
  end
end
