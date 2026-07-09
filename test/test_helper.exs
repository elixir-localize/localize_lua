# Locale-variance tests need CLDR data beyond the bundled `en` locale and reach
# the Localize CDN to fetch it. They are excluded by default so `mix test` is
# green offline; run them with `mix test --include locales`.
ExUnit.start(exclude: [:locales])
