# Using Localize.Lua in Lua

`Localize.Lua` installs a `localize` table into a [Lua](https://hexdocs.pm/lua) (Luerl) VM. Once installed, Lua scripts format numbers, money, dates, units, lists and MessageFormat 2 messages with full CLDR locale awareness — every call is an ordinary Elixir call into [Localize](https://hexdocs.pm/localize) running on the BEAM.

This guide covers how to drive the API from Lua, how values cross the Elixir↔Lua boundary, and where the current edges — and the opportunities — are.

## Installing

`Localize.Lua.install/1` adds the `localize` table to any `t:Lua.t/0`:

```elixir
lua = Localize.Lua.install(Lua.new())
{[html], _lua} = Lua.eval!(lua, script)
```

For a one-off evaluation, `Localize.Lua.eval/2` and `Localize.Lua.eval!/2` install and run in a single call:

```elixir
Localize.Lua.eval!(~S[return localize.currency(1234.56, "USD")])
#=> ["$1,234.56"]
```

## Setting the locale once

Every `localize.*` function takes an optional `locale` in its options table. But the locale is **per-process**, and Luerl runs inside the calling Elixir process, so the ergonomic pattern is to set the locale once before evaluating and let option-less calls inherit it:

```elixir
Localize.put_locale(:de)
Localize.Lua.eval!(~S[return localize.number(1234.5)])
#=> ["1.234,5"]
```

A per-call `locale` option always wins over the process locale:

```elixir
Localize.put_locale(:de)
Localize.Lua.eval!(~S[return localize.number(1234.5, {locale = "en"})])
#=> ["1,234.5"]
```

> *"Set the reader's locale once at the top of the render; the template just says `localize.number(total)` and it comes out right."*

## The functions

Each function takes primitive Lua values and an optional trailing **options table**, and returns a **string**.

```lua
localize.number(1234.5)                              -- "1,234.5"
localize.number(1234.56, {currency = "USD"})         -- "$1,234.56"
localize.currency(1234.56, "EUR", {locale = "de"})   -- "1.234,56 €"
localize.percent(0.56)                               -- "56%"

localize.date("2025-07-10", {format = "long"})       -- "July 10, 2025"
localize.time("14:30:00")                            -- "2:30:00 PM"
localize.datetime("2025-07-10T14:30:00Z")            -- "Jul 10, 2025, ..."
localize.relative(-3, "day")                         -- "3 days ago"

localize.unit(42, "kilometer", {format = "short"})   -- "42 km"
localize.list({"a", "b", "c"})                       -- "a, b, and c"

localize.territory_name("AU")                        -- "Australia"
localize.language_name("de")                         -- "German"
```

### Options tables

Options are a Lua table whose keys mirror the underlying `Localize` option:

```lua
localize.number(1234.56, {currency = "USD", fractional_digits = 0})  -- "$1,235"
localize.date("2025-07-10", {locale = "fr", format = "long"})        -- "10 juillet 2025"
```

Unknown keys are ignored. `format` and `style` values are given as strings (`"long"`, `"short"`, `"percent"`); a value the library does not recognise is passed through unchanged, so custom number patterns like `"#,##0.00"` still work.

### Dates and times are ISO 8601 strings

Luerl has no date type, so date/time functions take **ISO 8601 strings**, not tables:

```lua
localize.date("2025-07-10")                 -- a calendar date
localize.time("14:30:00")                   -- a wall-clock time
localize.datetime("2025-07-10T14:30:00Z")   -- a zoned or naive datetime
```

### Pluralisation with MessageFormat 2

`localize.message` formats an [MF2](https://hexdocs.pm/localize) message with a bindings table, applying CLDR plural rules — the thing string interpolation cannot do:

```lua
local mf2 = ".input {$count :integer}\n"
         .. ".match $count\n"
         .. " one {{{$count} item}}\n"
         .. " *   {{{$count} items}}"

localize.message(mf2, {count = 1})   -- "1 item"
localize.message(mf2, {count = 5})   -- "5 items"
```

Note that MF2 messages contain real newlines; build them with `\n` in Lua string literals (or concatenation as above), not by pasting a multi-line block.

## Never raises on the render path

Every binding returns a string and, on any error, falls back to a safe rendering of its input rather than raising:

```lua
localize.date("not-a-date")            -- "not-a-date"
localize.territory_name("ZZZ")         -- "ZZZ"
localize.number(10, {locale = "zz"})   -- still a string, formatted with the root locale
```

This is deliberate: a template authored by a non-programmer must never be able to crash the host render path. There is no error return to branch on — if a value cannot be formatted, you get a reasonable string back.

## Locale data

Only the `en` locale ships with `Localize`. Install the locales your application serves once, at build time:

```sh
mix localize.download_locales de fr ja
```

A call for a locale that has not been installed formats with the root locale rather than raising, so a missing locale degrades to a plain rendering rather than an error.

## Limitations

* **Formatting only, one direction.** The table formats Elixir/Localize values *to* strings. There is no parsing back (string → number/date), no collation, and no interval or duration formatting yet — see *Opportunities*.

* **Strings out, primitives in.** A binding cannot return a table or a rich value to Lua; it returns a string. Values into a binding are Lua primitives (number, string, table), so an Elixir `Decimal` or `Date` cannot be passed through — hand a number or an ISO string instead.

* **Numbers are floats.** Luerl represents Lua numbers as floats, so a currency amount carried through Lua as `1234.56` is a float. For money where exact precision matters, format on the Elixir side, or pass minor units as an integer and set `fractional_digits`, rather than round-tripping a large amount through a Lua float.

* **Locale is process-scoped.** Setting `Localize.put_locale/1` affects the whole process. Inside one evaluation you cannot have two ambient locales at once; pass an explicit `locale` option when a single template must mix locales.

* **No per-call option pre-validation.** `Localize` offers pre-validated option structs for hot loops; the Lua surface re-resolves options on every call. A render is not a tight loop, so this rarely matters, but a template formatting tens of thousands of values will pay for it.

* **Display-name codes must be known.** `territory_name` / `language_name` resolve the code against loaded CLDR data; an unknown or unloaded code falls back to the raw code string.

## Opportunities

* **More of Localize.** Natural next bindings: interval and duration formatting (`Localize.Interval`, `Localize.Duration`), locale-aware sorting (`Localize.Collation.sort/2`), calendar names (`Localize.Calendar`), number *parsing*, and relative time from two datetimes rather than a bare number.

* **A `localize.set_locale(...)` helper.** A binding that calls `Localize.put_locale/1` from Lua would let a template header set the locale once — with the process-scoped caveat above made explicit.

* **Custom MF2 functions.** `Localize.Message` supports registering custom MF2 functions; exposing a registration path would let a host add domain formatters (e.g. an order-status selector) usable from templates.

* **Pre-validated formatters.** For high-volume rendering, a binding that accepts a pre-built number-format options struct — validated once on the Elixir side (see Localize's performance rules) and stored in the VM — would remove per-call option resolution.

If you reach for one of these, the mechanism is always the same: add a `deflua` to `Localize.Lua.API` that decodes its Lua arguments, calls the relevant `Localize` function, and returns a string with a graceful fallback.
