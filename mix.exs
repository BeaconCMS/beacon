defmodule Beacon.MixProject do
  use Mix.Project

  @version "0.1.0-dev"

  def project do
    [
      app: :beacon,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      name: "Beacon",
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix],
        list_unused_filters: true
      ]
    ]
  end

  def application do
    [
      mod: {Beacon.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:accent, "~> 1.1"},
      {:brotli, "~> 0.3.2"},
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.5", only: :dev},
      {:ex_doc, "~> 0.29", only: :docs},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.20"},
      {:hackney, "~> 1.16", only: [:dev, :test]},
      {:heroicons, "~> 0.5"},
      {:image, "~> 0.32"},
      {:jason, "~> 1.0"},
      {:solid, "~> 0.14"},
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_view, "~> 0.19"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_view, "~> 2.0", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.6", only: [:dev, :test]},
      {:postgrex, "~> 0.16"},
      {:safe_code, github: "TheFirstAvenger/safe_code"},
      {:tailwind, "~> 0.2"},
      live_monaco_editor_dep()
    ]
  end

  defp live_monaco_editor_dep do
    if path = System.get_env("LIVE_MONACO_EDITOR_PATH") do
      {:live_monaco_editor, path: path}
    else
      {:live_monaco_editor, "~> 0.1"}
    end
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      dev: ["ecto.reset", "run --no-halt dev.exs"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing --no-assets", "esbuild.install --if-missing"],
      "assets.build": ["esbuild cdn", "esbuild cdn_min"]
    ]
  end

  defp docs do
    [
      main: "Beacon",
      source_ref: "v#{@version}",
      source_url: "https://github.com/BeaconCMS/beacon",
      groups_for_modules: [
        Content: [
          Beacon.Content,
          Beacon.Content.Component,
          Beacon.Content.Layout,
          Beacon.Content.LayoutEvent,
          Beacon.Content.LayoutSnapshot,
          Beacon.Content.Page,
          Beacon.Content.Page.Event,
          Beacon.Content.Page.Helper,
          Beacon.Content.PageEvent,
          Beacon.Content.PageSnapshot,
          Beacon.Content.Stylesheet,
          Beacon.Content.Snippets.Helper,
          Beacon.Template,
          Beacon.Template.HEEx,
          Beacon.Template.Markdown,
          Beacon.DataSource.Behaviour
        ],
        "Media Library": [
          Beacon.MediaLibrary,
          Beacon.MediaLibrary.Asset,
          Beacon.MediaLibrary.Backend,
          Beacon.MediaLibrary.Backend.Repo,
          Beacon.MediaLibrary.Backend.S3,
          Beacon.MediaLibrary.Backend.S3.Signed,
          Beacon.MediaLibrary.Backend.S3.Unsigned,
          Beacon.MediaTypes,
          Beacon.MediaLibrary.Processors.Default,
          Beacon.MediaLibrary.Processors.Image,
          Beacon.MediaLibrary.UploadMetadata
        ],
        "Authn and Authz": [
          Beacon.Authorization.Behaviour,
          Beacon.Authorization.DefaultPolicy
        ],
        Web: [
          BeaconWeb.PageLive,
          BeaconWeb.Components
        ],
        "RESTful API": [
          BeaconWeb.API.PageController,
          BeaconWeb.API.ComponentController
        ],
        Extensibility: [
          Beacon.Config,
          Beacon.Lifecycle,
          Beacon.Content.PageField,
          Beacon.Template.LoadMetadata,
          Beacon.Template.RenderMetadata
        ],
        Execution: [
          Beacon.Router,
          Beacon.Loader,
          Beacon.Registry,
          Beacon.RuntimeCSS,
          Beacon.RuntimeJS,
          Beacon.TailwindCompiler
        ],
        Types: [
          Beacon.Types.Atom,
          Beacon.Types.Binary,
          Beacon.Types.Site
        ],
        Exceptions: [
          Beacon.LoaderError,
          Beacon.DataSourceError,
          Beacon.AuthorizationError,
          Beacon.ParserError,
          BeaconWeb.NotFoundError
        ]
      ],
      groups_for_functions: [
        "Functions: Layouts": &(&1[:type] == :layouts),
        "Functions: Pages": &(&1[:type] == :pages),
        "Functions: Page Variants": &(&1[:type] == :page_variants),
        "Functions: Stylesheets": &(&1[:type] == :stylesheets),
        "Functions: Components": &(&1[:type] == :components),
        "Functions: Snippets": &(&1[:type] == :snippets)
      ]
    ]
  end
end
