# Changelog

## 0.1.0

Initial release. `Localize.Lua.install/1` adds a `localize` table to a Lua (Luerl) VM, exposing `Localize`-backed number, currency, percent, date, time, datetime, relative-time, unit, list, MessageFormat 2, and display-name formatting to Lua scripts. Every binding is locale-aware, returns a string, and falls back gracefully rather than raising on the host render path.
