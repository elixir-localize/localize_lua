# Using Localize.Lua with AshLua

[AshLua](https://github.com/ash-project/ash_lua) embeds Lua scripts in Ash, giving them a consistent actor, tenant and context and a bridge to Ash actions. It is built on the same [`lua`](https://hexdocs.pm/lua) (Luerl) package that `Localize.Lua` targets, so **an AshLua VM is a `Lua` VM** — and `Localize.Lua` installs onto it directly. There is no separate AshLua binding: the same `Localize.Lua.install/1` you use for a plain VM works here.

## Installing

`AshLua.new/1` returns a `t:Lua.t/0` with Ash bindings installed. Add the `localize` table with `Localize.Lua.install/1`:

```elixir
lua =
  AshLua.new(otp_app: :my_app)
  |> Localize.Lua.install()

{[price], _lua} = Lua.eval!(lua, ~S[return localize.currency(order.total, "EUR", {locale = user.locale})])
```

AshLua also accepts a pre-built VM through its `:lua` option, so you can install `localize` first and let AshLua layer its bindings on top — either order gives you a VM with both:

```elixir
lua = AshLua.new(otp_app: :my_app, lua: Localize.Lua.install(Lua.new()))
```

For repeated evaluation, `AshLua.eval!/2` takes the same `:lua`:

```elixir
AshLua.eval!(script, otp_app: :my_app, lua: Localize.Lua.install(Lua.new()))
```

## Both worlds in one script

Once installed, an Ash-Lua script formats data with `localize.*` right alongside its Ash calls:

```lua
local order = cms.orders.get({ id = order_id })

return "Total: " .. localize.currency(order.total, order.currency, {locale = ctx.locale})
    .. " — " .. localize.relative(order.placed_days_ago, "day", {locale = ctx.locale})
```

> *"Fetch the order **through Ash**, then render its total as **currency** and its age as **relative** time in the reader's locale."*

Ash owns the data access; `Localize.Lua` owns the locale-aware formatting. Neither touches the other's globals.

## Relationship to ash_cms

[ash_cms](https://codeberg.org/olivermt/ash_cms) renders its Lua templates through AshLua, so the same integration applies one layer up — see [Using Localize.Lua in Ash CMS](using-in-ash-cms.html) for wiring it into the CMS render path specifically.

## Locale data and safety

The locale-data and safety notes from [Using Localize.Lua in Lua](using-in-lua.html) apply unchanged: only the `en` locale ships with Localize (install others with `mix localize.download_locales`), and every `localize.*` call returns a string and falls back gracefully, so a template can never crash the evaluation.
