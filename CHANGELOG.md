# Changelog

## 0.2.0 — 2026-07-30

### Changes

* Updates to `lua: "~> 1.0"

* Updates to `localize: "~> 1.0-rc"

## 0.1.0

Initial release. `Localize.Lua.install/1` adds a `localize` table to a Lua (Luerl) VM, exposing `Localize`-backed number, currency, percent, date, time, datetime, relative-time, unit, list, MessageFormat 2, and display-name formatting to Lua scripts. Every binding is locale-aware, returns a string, and falls back gracefully rather than raising on the host render path.
