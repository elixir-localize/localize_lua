# Localize.Lua usage rules

Rules for LLM coding agents using `Localize.Lua` as a dependency.

## What it is

`Localize.Lua` exposes `Localize`'s locale-aware formatting to the Lua (Luerl) VM. It installs a `localize` table into a `t:Lua.t/0`; Lua scripts then call `localize.number(...)`, `localize.date(...)`, etc.

## Core conventions

* Install the API with `Localize.Lua.install(lua)` before evaluating a script that uses `localize.*`. For one-shot evaluation use `Localize.Lua.eval/2` (returns `{:ok, results}`) or `Localize.Lua.eval!/2` (returns results, raises on a Lua error).

* Every `localize.*` function returns a **string** and never raises on bad input — it falls back to a safe rendering of its argument. Do not write Lua that branches on an error return; there isn't one.

* Options are passed as a trailing Lua **table**: `localize.number(1, {locale = "de", format = "percent"})`. Unknown keys are ignored. Recognised keys map to the options of the underlying `Localize` function.

* Locale-valued options are strings (`locale = "en-AU"`). Atom-valued options (`format`, `style`) are given as strings and resolved through a static allowlist; unrecognised values pass through as strings for custom patterns.

## Function map

| Lua | Backed by |
|---|---|
| `localize.number(value, options?)` | `Localize.Number.to_string/2` |
| `localize.currency(value, code, options?)` | `Localize.Number.to_string/2` with `:currency` |
| `localize.percent(value, options?)` | `Localize.Number.to_string/2` with `format: :percent` |
| `localize.date(iso, options?)` | `Localize.Date.to_string/2` |
| `localize.time(iso, options?)` | `Localize.Time.to_string/2` |
| `localize.datetime(iso, options?)` | `Localize.DateTime.to_string/2` |
| `localize.relative(number, unit, options?)` | `Localize.DateTime.Relative.to_string/2` |
| `localize.unit(value, unit_name, options?)` | `Localize.Unit.new/2` + `to_string/2` |
| `localize.list(array, options?)` | `Localize.List.to_string/2` |
| `localize.message(mf2, bindings?)` | `Localize.Message.format/3` |
| `localize.territory_name(code, options?)` | `Localize.Territory.display_name/2` |
| `localize.language_name(code, options?)` | `Localize.Language.display_name/2` |

* Date/time functions take **ISO 8601 strings** (`"2025-07-10"`, `"14:30:00"`, `"2025-07-10T14:30:00Z"`), not Lua tables.

* `localize.list` takes a Lua **array** (`{"a", "b", "c"}`).

* `localize.message` takes an MF2 string and a bindings table (`{count = 3}`); this is the path to CLDR-correct pluralisation.

## Locale data

Only `en` ships with `Localize`. Run `mix localize.download_locales de fr ...` at build time for every locale you serve. A call for an uninstalled locale formats with the root locale rather than raising.
