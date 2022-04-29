defmodule Beacon.MixProject do
  use Mix.Project

  def project do
    [
      app: :beacon,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Beacon.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.6"},
      {:gettext, "~> 0.18"},
      {:phoenix_pubsub, "2.0.0"},
      {:phoenix_live_view, "~> 0.17.5"},
      {:postgrex, ">= 0.0.0"},
      {:safe_code, github: "TheFirstAvenger/safe_code"}
    ]
  end
end
