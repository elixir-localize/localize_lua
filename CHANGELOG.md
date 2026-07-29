# Changelog

## 1.0.0 — 2026-07-30

Initial release.

### Highlights

* `Localize.Lua.install/1` adds a `localize` table to a [Lua](https://hexdocs.pm/lua) (Luerl) VM, exposing [Localize](https://hexdocs.pm/localize)-backed formatting to Lua scripts: number, currency, percent, date, time, datetime, relative-time, unit, list, MessageFormat 2, and territory/language display names.

* `Localize.Lua.eval/2` and `eval!/2` install the API and evaluate a script in one call.

* Every binding is locale-aware, returns a string, and falls back to a safe rendering of its input rather than raising — an untrusted template can never crash the host render path.

* The exposed surface is a curated allowlist of pure formatting functions with no filesystem or network access, and Lua-sourced option values never reach `String.to_atom/1`, so the template sandbox is not widened.

* Built on `lua ~> 1.0` and `localize ~> 1.0`. See the [README](https://hexdocs.pm/localize_lua/readme.html) and guides for full documentation.
