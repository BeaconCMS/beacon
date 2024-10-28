defmodule Mix.Tasks.Beacon.InstallTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  setup do
    [igniter: phoenix_project()]
  end

  test "copy js config file", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("beacon.install")
    |> Igniter.compose_task("beacon.gen.tailwind_config")
    |> assert_creates("assets/beacon.tailwind.config.js")
  end

  test "add esbuild profile", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config")
    |> assert_has_patch("config/config.exs", """
       41 + |  ],
       42 + |  beacon_tailwind_config: [
       43 + |    args: ~w(beacon.tailwind.config.js --bundle --format=esm --target=es2020 --outfile=../priv/beacon.tailwind.config.bundle.js),
       44 + |    cd: Path.expand("../assets", __DIR__),
       45 + |    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    41 46   |  ]
    """)
  end

  test "add endpoint watcher", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config")
    |> assert_has_patch("config/dev.exs", """
       18 + |    esbuild: {Esbuild, :install_and_run, [:beacon_tailwind_bundle, ~w(--watch)]},
    """)
  end

  test "add esbuild cmd into assets.build alias", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config")
    |> assert_has_patch("mix.exs", """
       72 + |      "assets.build": ["tailwind test", "esbuild test", "esbuild beacon_tailwind_config"],
    """)
  end

  test "add esbuild cmd into assets.deploy alias", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("beacon.install")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.tailwind_config")
    |> assert_has_patch("mix.exs", """
       73 + |      "assets.deploy": ["tailwind test --minify", "esbuild test --minify", "phx.digest", "esbuild beacon_tailwind_config --minify"]
    """)
  end
end
