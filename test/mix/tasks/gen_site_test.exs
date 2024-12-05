defmodule Mix.Tasks.Beacon.GenSiteTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  @opts_my_site ~w(--site my_site --path /)
  @opts_other_site ~w(--site other --path /other)

  describe "options validation" do
    test "validates site" do
      assert_raise Mix.Error, fn ->
        Igniter.compose_task(test_project(), "beacon.gen.site", ~w(--site nil))
      end

      assert_raise Mix.Error, fn ->
        Igniter.compose_task(test_project(), "beacon.gen.site", ~w(--site beacon_my_site))
      end
    end

    test "validates path" do
      assert_raise Mix.Error, fn ->
        Igniter.compose_task(test_project(), "beacon.gen.site", ~w(--site my_site --path nil))
      end
    end
  end

  test "do not duplicate files and configs" do
    phoenix_project()
    |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
    |> assert_unchanged()
  end

  describe "migration" do
    setup do
      [project: phoenix_project()]
    end

    test "create initial migration", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_creates("priv/repo/migrations/0_create_beacon_tables.exs", """
      defmodule Test.Repo.Migrations.CreateBeaconTables do
        use Ecto.Migration

        def up, do: Beacon.Migration.up()
        def down, do: Beacon.Migration.down()
      end
      """)
    end
  end

  describe "router" do
    setup do
      project =
        phoenix_project()
        |> Igniter.compose_task("beacon.install", [])
        |> Igniter.Test.apply_igniter!()

      [project: project]
    end

    test "use beacon", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      4 + |  use Beacon.Router
      """)
    end

    test "add Beacon.Plug to beacon pipeline", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      6 + |  pipeline :beacon do
      7 + |    plug Beacon.Plug
      8 + |  end
      """)
    end

    test "mount site in router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      24 + |    pipe_through [:browser, :beacon]
      25 + |    beacon_site "/", site: :my_site
      """)
    end

    test "mount another site in router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      24 24   |    pipe_through [:browser, :beacon]
      25 25   |    beacon_site "/", site: :my_site
         26 + |    beacon_site "/other", site: :other
      """)
    end
  end

  describe "config" do
    setup do
      [project: phoenix_project()]
    end

    test "add site config in runtime", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("config/runtime.exs", """
      2 + |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]
      """)
    end

    test "add another site config in runtime", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("config/runtime.exs", """
      2     - |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]
      3   2   |
          3 + |config :beacon,
          4 + |  my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router],
          5 + |  other: [site: :other, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]
      """)
    end
  end

  describe "application" do
    setup do
      [project: phoenix_project()]
    end

    test "add beacon child with site", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test/application.ex", """
      20 + |      TestWeb.Endpoint,
      21 + |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site)]]}
      """)
    end

    test "add another site into existing beacon child", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("lib/test/application.ex", """
      21    - |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site)]]}
         21 + |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site), Application.fetch_env!(:beacon, :other)]]}
      """)
    end
  end
end
