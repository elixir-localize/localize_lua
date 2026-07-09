defmodule Localize.Lua.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-localize/localize_lua"

  def project do
    [
      app: :localize_lua,
      version: @version,
      name: "Localize.Lua",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      dialyzer: [
        plt_add_apps: [:mix],
        flags: [
          :error_handling,
          :unknown,
          :extra_return,
          :missing_return
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Locale-aware number, date, currency, unit, list and MessageFormat 2 " <>
      "bindings for the Lua (Luerl) VM, backed by Localize."
  end

  defp deps do
    [
      {:lua, "~> 1.0.0-rc"},
      {:localize, "~> 0.48"},
      {:ex_doc, "~> 0.34", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ] ++ maybe_json_polyfill()
  end

  # Localize requires OTP 27+'s built-in `:json` module. On OTP 26 it needs the
  # json_polyfill (EEP 68) — provided here for THIS project's own dev/test/CI
  # only. `only:` deps never enter the hex package requirements, so OTP 26
  # consumers add {:json_polyfill, "~> 0.2 or ~> 1.0"} to their own deps. The
  # conditional avoids fetching it on OTP >= 27, where the polyfill's own build
  # fails because `:json` is already built in.
  defp maybe_json_polyfill do
    if Code.ensure_loaded?(:json) do
      []
    else
      [{:json_polyfill, "~> 0.2 or ~> 1.0", only: [:dev, :test]}]
    end
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: [
        "lib",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*",
        "usage-rules.md"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "guides/using-in-lua.md",
        "guides/using-in-ash-cms.md",
        "CHANGELOG.md",
        "LICENSE.md"
      ],
      groups_for_extras: [
        Guides: ~r"guides/"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
