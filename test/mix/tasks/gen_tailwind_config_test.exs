defmodule Mix.Tasks.Beacon.GenTailwindConfigTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  @opts_my_site ~w(--site my_site)

  setup do
    [project: phoenix_project()]
  end

  test "copy js config file", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> Igniter.compose_task("beacon.gen.tailwind_config", @opts_my_site)
    |> assert_creates("assets/beacon.tailwind.config.js")
  end

  test "add esbuild profile", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config", @opts_my_site)
    |> assert_has_patch("config/config.exs", """
       41 + |  ],
       42 + |  beacon_tailwind_config: [
       43 + |    args: ~w(beacon.tailwind.config.js --bundle --format=esm --target=es2020 --outfile=../priv/beacon.tailwind.config.bundle.js),
       44 + |    cd: Path.expand("../assets", __DIR__),
       45 + |    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    41 46   |  ]
    """)
  end

  test "add endpoint watcher", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config", @opts_my_site)
    |> assert_has_patch("config/dev.exs", """
       20 + |    beacon_tailwind_config: {Esbuild, :install_and_run, [:beacon_tailwind_config, ~w(--watch)]}
    """)
  end

  test "add esbuild cmd into assets.build alias", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config", @opts_my_site)
    |> assert_has_patch("mix.exs", """
       71 + |      "assets.build": ["tailwind test", "esbuild test", "esbuild beacon_tailwind_config"],
    """)
  end

  test "add esbuild cmd into assets.deploy alias", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config", @opts_my_site)
    |> assert_has_patch("mix.exs", """
    72 + |      "assets.deploy": ["tailwind test --minify", "esbuild test --minify", "phx.digest", "esbuild beacon_tailwind_config --minify"]
    """)
  end

  test "add tailwind_config into site config", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config", @opts_my_site)
    |> assert_has_patch("config/runtime.exs", """
    2     - |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]
    3   2   |
        3 + |config :beacon,
        4 + |  my_site: [
        5 + |    site: :my_site,
        6 + |    repo: Test.Repo,
        7 + |    endpoint: TestWeb.Endpoint,
        8 + |    router: TestWeb.Router,
        9 + |    tailwind_config: Path.join(Application.app_dir(:test, "priv"), "beacon.tailwind.config.bundle.js")
       10 + |  ]
    """)
  end
end
