# Localize.Lua

Locale-aware formatting for the [Lua](https://hexdocs.pm/lua) (Luerl) VM, backed by [Localize](https://hexdocs.pm/localize).

`Localize.Lua` installs a small `localize` table into a Luerl VM so that Lua scripts — such as the templates rendered by [`ash_cms`](https://codeberg.org/olivermt/ash_cms) — can format numbers, currencies, dates, times, units, lists and MessageFormat 2 messages with full CLDR locale awareness.

Because Luerl runs entirely on the BEAM, there is no foreign runtime to bridge: each `localize.*` call from Lua is an ordinary Elixir call into `Localize`. The exposed surface is a curated allowlist of pure formatting functions — no filesystem, no network — so it is safe to hand to untrusted template authors.

## Installation

```elixir
def deps do
  [
    {:localize_lua, "~> 0.1"}
  ]
end
```

`Localize` requires OTP 27+'s built-in `:json` module. On **OTP 26**, also add the polyfill to your own deps, otherwise `Localize` raises at application start:

```elixir
{:json_polyfill, "~> 0.2 or ~> 1.0"}
```

## Usage

Install the API into a VM and evaluate a script:

```elixir
lua = Localize.Lua.install(Lua.new())

{[price], _lua} = Lua.eval!(lua, ~S[return localize.currency(1234.56, "EUR", {locale = "de"})])
price
#=> "1.234,56 €"
```

Or use the one-shot helpers:

```elixir
Localize.Lua.eval!(~S[return localize.percent(0.56)])
#=> ["56%"]
```

### From a Lua template

Once installed, a template reads as prose:

```lua
local price   = localize.currency(item.price, store.currency, {locale = user.locale})
local shipped = localize.date(order.shipped_on, {locale = user.locale, format = "long"})
local summary = localize.message(
  ".input {$count :integer}\n.match $count\n one {{{$count} item}}\n * {{{$count} items}}",
  {count = #order.items}
)
```

> *"The **price** is the item price as **currency** in the user's locale. **Shipped** is the ship date in **long** form. The **summary** pluralises the item count with CLDR rules — `1 item`, `5 items` — in whatever language the user reads."*

## The `localize` API

| Lua call | Result (en) |
|---|---|
| `localize.number(1234.5)` | `1,234.5` |
| `localize.number(1234.56, {currency = "USD"})` | `$1,234.56` |
| `localize.currency(1234.56, "EUR", {locale = "de"})` | `1.234,56 €` |
| `localize.percent(0.56)` | `56%` |
| `localize.date("2025-07-10", {format = "long"})` | `July 10, 2025` |
| `localize.time("14:30:00")` | `2:30:00 PM` |
| `localize.datetime("2025-07-10T14:30:00Z")` | `Jul 10, 2025, ...` |
| `localize.relative(-3, "day")` | `3 days ago` |
| `localize.unit(42, "kilometer", {format = "short"})` | `42 km` |
| `localize.list({"a", "b", "c"})` | `a, b, and c` |
| `localize.message(mf2, {count = 3})` | (MF2 with CLDR plurals) |
| `localize.territory_name("AU")` | `Australia` |
| `localize.language_name("de")` | `German` |

Every function accepts an optional trailing options table (`{locale = ..., format = ...}`) forwarded to the corresponding `Localize` function.

## Safety

* **Never raises on the render path.** Every binding returns a string and falls back to a safe rendering of its input on any error — an unknown locale, an unparseable date, a malformed table — so a broken template degrades gracefully instead of crashing the host.

* **No atom-table exhaustion.** Option values sourced from a Lua script are never passed to `String.to_atom/1`; atom-valued options are resolved through a static compile-time allowlist.

## Locale data

Only the `en` locale ships with `Localize`. Install the locales your application serves once at build time:

```sh
mix localize.download_locales de fr ja
```

A call for a locale that has not been installed formats with the root locale rather than raising.

## Development

The standard gates:

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test                        # `en` only — always green offline
mix test --only locales         # cross-locale, downloads CLDR data
mix credo --strict
mix dialyzer
mix docs
```

## License

Apache-2.0. See [LICENSE.md](LICENSE.md).
