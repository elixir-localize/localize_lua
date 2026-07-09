# Using Localize.Lua in Ash CMS

[Ash CMS](https://codeberg.org/olivermt/ash_cms) renders storefronts and editor pages from **Lua templates**. Those templates run in a Luerl VM that the renderer builds for every page — and that VM is exactly what `Localize.Lua` extends. This guide shows how to wire `localize` into the Ash CMS render path and how it complements the translation helpers Ash CMS already ships.

## Two jobs: translating copy vs. formatting data

Ash CMS already installs Elixir-backed i18n helpers into every template VM. In `AshCms.Renderer.Lua`, the private `put_i18n/3` step sets `t`, `lt`, `i18ntext` and the `i18n.*` table onto the VM — these resolve **label keys** to localized copy:

```lua
t("page.home.title")        -- looks up a translation row for the active locale
lt(product.name_label)      -- resolves a label reference
```

That answers *"what words do we show?"* It does **not** answer *"how do we render this number, price, or date for this locale?"* — `t` has no CLDR number, date or plural machinery behind it.

`Localize.Lua` fills that second job. The two are complementary:

| Concern | Helper | Example |
|---|---|---|
| Translated copy | `t` / `lt` (Ash CMS) | `t("cart.checkout")` → `"Zur Kasse"` |
| Formatted data | `localize.*` | `localize.currency(p, "EUR", {locale = l})` → `"9,99 €"` |

## Wiring it in

`localize` belongs in the same place as `t` and `lt`: the `put_i18n/3` step, which runs on every render path (page, fragment and preview). Because Ash CMS builds the VM internally, the cleanest integration is a one-line addition there — the same shape as the existing `Lua.set!` translation installs.

In `AshCms.Renderer.Lua`:

```elixir
defp put_i18n(lua, site, opts) do
  i18n_opts = I18nRuntime.opts(site, opts)
  context = I18n.context(i18n_opts) |> Response.normalize()

  lua
  |> Lua.set!(["ctx"], context)
  |> Lua.set!(["i18n"], context)
  |> Lua.set!(["t"], translate_fun(i18n_opts))
  |> Lua.set!(["lt"], translate_ref_fun(i18n_opts))
  # ... existing i18n installs ...
  |> Localize.Lua.install()          # <-- adds the `localize` table
end
```

Add `{:localize_lua, "~> 0.1"}` to the Ash CMS `mix.exs` deps. That is the whole integration — every template can now call `localize.*`.

> This mirrors how `t`/`lt` are installed; it is not a workaround. If you would rather gate it, wrap the install in a config check (`if Application.get_env(:ash_cms, :localize_formatting, true), do: ...`).

## Give templates the reader's locale for free

`localize.*` functions default to the **process locale** when no `locale` option is given. Ash CMS already resolves the active locale into `i18n_opts`, so set it once around the evaluation and templates need not repeat it. In `eval_template`, wrap the `Lua.eval!` call:

```elixir
Localize.with_locale(i18n_opts[:locale], fn ->
  Lua.eval!(lua, chunk)
end)
```

Now a template says `localize.number(total)` and it comes out in the reader's locale. A template can still pass `{locale = ctx.locale}` explicitly when it needs to — `ctx.locale` is already on the VM — and an explicit option always wins.

## A worked template

A product card mixing translated labels with formatted data:

```lua
local locale = ctx.locale

return "<article class='product'>"
  .. "<h3>" .. lt(product.name) .. "</h3>"
  .. "<p class='price'>" .. localize.currency(product.price, store.currency, {locale = locale}) .. "</p>"
  .. "<p class='stock'>" .. localize.message(
       ".input {$n :integer}\n.match $n\n one {{{$n} left in stock}}\n * {{{$n} left in stock}}",
       {n = product.stock}
     ) .. "</p>"
  .. "<p class='added'>" .. t("product.added") .. " "
     .. localize.relative(product.added_days_ago, "day", {locale = locale}) .. "</p>"
  .. "</article>"
```

> *"The heading is the product's **translated name**. The price is its amount as **currency** in the reader's locale. The stock line **pluralises** the count with CLDR rules. The footer joins the **translated** label 'Added' with a **relative** time — `3 days ago`, or `vor 3 Tagen` for a German reader."*

Every value in that template reads as a sentence a merchandiser would say, and none of it hand-rolls a format string.

## Superseding `%{}` interpolation

`AshCms.I18n` interpolates variables into label copy with a simple `%{name}` replacement. That is fine for static substitution, but it cannot pluralise or localise the interpolated value — `%{count} items` is always `"items"`, and `%{price}` is inserted verbatim.

Where a message depends on a **count** or needs a **formatted value**, reach for `localize.message` instead, and store the message as MF2:

```lua
-- Instead of a label "%{count} items in your cart"
localize.message(
  ".input {$count :integer}\n.match $count\n one {{{$count} item in your cart}}\n * {{{$count} items in your cart}}",
  {count = cart.size}
)
```

This can be adopted incrementally — keep `t`/`lt` for plain copy, and move only count- or value-bearing strings to `localize.message`.

## Safety in the CMS context

Ash CMS templates may be authored by non-developers in the editor. `Localize.Lua` suits that setting:

* **No new capability is exposed.** `localize.*` is a curated allowlist of pure formatting functions — no filesystem, no network, no Ash access — so it does not widen the template sandbox.

* **It never crashes a render.** Every binding returns a string and falls back to a safe rendering on bad input, so a mistyped locale or date in a template degrades gracefully instead of 500-ing the page.

## Checklist

1. Add `{:localize_lua, "~> 0.1"}` to Ash CMS deps.
2. Append `|> Localize.Lua.install()` to `put_i18n/3`.
3. (Recommended) wrap template evaluation in `Localize.with_locale/2` using the resolved i18n locale.
4. Run `mix localize.download_locales <locales>` for every locale the site serves.
5. Use `t`/`lt` for copy and `localize.*` for data; move count-bearing strings to `localize.message`.
