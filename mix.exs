defmodule Beacon.MixProject do
  use Mix.Project

  def project do
    [
      app: :beacon,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
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
      {:ecto_sql, "~> 3.6"},
      {:gettext, "~> 0.20"},
      {:heroicons, "~> 0.5"},
      # TODO remove override after the final Phoenix 1.7 is released
      {:phoenix, "~> 1.7.0-rc.0", override: true},
      {:phoenix_live_view, "~> 0.18", override: true},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_view, "~> 2.0", only: :test},
      {:postgrex, ">= 0.0.0"},
      {:safe_code, github: "TheFirstAvenger/safe_code"},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:floki, ">= 0.30.0", only: :test},
      {:plug_cowboy, "~> 2.1", only: :test}
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
      setup: ["deps.get"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
