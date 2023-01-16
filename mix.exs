defmodule Beacon.MixProject do
  use Mix.Project

  @version "0.1.0-dev"

  def project do
    [
      app: :beacon,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      name: "Beacon",
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Beacon.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.4"},
      {:ex_doc, "~> 0.29", only: :docs},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.20"},
      {:heroicons, "~> 0.5"},
      {:jason, "~> 1.3"},
      {:mox, "~> 1.0", only: :test},
      # TODO remove override after the final Phoenix 1.7 is released
      {:phoenix, "~> 1.7.0-rc.0", override: true},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_view, "~> 0.18", override: true},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_view, "~> 2.0", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.6", only: [:dev, :test]},
      {:postgrex, ">= 0.0.0"},
      {:safe_code, github: "TheFirstAvenger/safe_code"},
      {:tailwind, "~> 0.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      dev: "run --no-halt dev.exs",
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["esbuild default --minify", "tailwind admin --minify"]
    ]
  end

  defp docs do
    [
      main: "Beacon",
      source_ref: "v#{@version}",
      source_url: "https://github.com/BeaconCMS/beacon"
    ]
  end
end
