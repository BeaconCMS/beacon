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
      elixirc_paths: elixirc_paths(Mix.env())
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
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.5", only: :dev},
      {:ex_brotli, "~> 0.3"},
      {:ex_doc, "~> 0.29", only: :docs},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.20"},
      {:hackney, "~> 1.16", only: [:dev, :test]},
      {:image, "~> 0.40"},
      {:jason, "~> 1.0"},
      {:solid, "~> 0.14"},
      phoenix_dep(),
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      phoenix_live_view_dep(),
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_view, "~> 2.0", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.6", only: [:dev, :test]},
      {:postgrex, "~> 0.16"},
      {:safe_code, github: "TheFirstAvenger/safe_code"},
      {:tailwind, "~> 0.2"},
      {:rustler, ">= 0.0.0", optional: true},
      {:faker, "~> 0.17", only: :test},
      live_monaco_editor_dep(),
      mdex_dep()
    ]
  end

  defp phoenix_dep do
    cond do
      env = System.get_env("PHOENIX_VERSION") -> {:phoenix, env}
      path = System.get_env("PHOENIX_PATH") -> {:phoenix, path}
      :default -> {:phoenix, "~> 1.7"}
    end
  end

  defp phoenix_live_view_dep do
    cond do
      env = System.get_env("PHOENIX_LIVE_VIEW_VERSION") -> {:phoenix_live_view, env}
      path = System.get_env("PHOENIX_LIVE_VIEW_PATH") -> {:phoenix_live_view, path}
      :default -> {:phoenix_live_view, "~> 0.20"}
    end
  end

  defp live_monaco_editor_dep do
    cond do
      path = System.get_env("LIVE_MONACO_EDITOR_PATH") -> {:live_monaco_editor, path: path}
      :default -> {:live_monaco_editor, "~> 0.1"}
    end
  end

  defp mdex_dep do
    cond do
      path = System.get_env("MDEX_PATH") -> {:mdex, path: path}
      :default -> {:mdex, "~> 0.1"}
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
          Beacon.Content.ErrorPage,
          Beacon.Content.Layout,
          Beacon.Content.LayoutEvent,
          Beacon.Content.LayoutSnapshot,
          Beacon.Content.LiveData,
          Beacon.Content.LiveDataAssign,
          Beacon.Content.Page,
          Beacon.Content.Page.Event,
          Beacon.Content.Page.Helper,
          Beacon.Content.PageEvent,
          Beacon.Content.PageEventHandler,
          Beacon.Content.PageSnapshot,
          Beacon.Content.PageVariant,
          Beacon.Content.Stylesheet,
          Beacon.Content.Snippets.Helper,
          Beacon.Template,
          Beacon.Template.HEEx,
          Beacon.Template.Markdown
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
          Beacon.Authorization.Policy,
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
        "Functions: Snippets": &(&1[:type] == :snippets),
        "Functions: Page Event Handlers": &(&1[:type] == :page_event_handlers),
        "Functions: Error Pages": &(&1[:type] == :error_pages),
        "Functions: Live Data": &(&1[:type] == :live_data)
      ]
    ]
  end
end
