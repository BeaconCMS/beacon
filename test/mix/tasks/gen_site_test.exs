defmodule Mix.Tasks.Beacon.Gen.SiteTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  @opts ~w(--site my_site --path / --yes)

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

  describe "generator" do
    setup do
      [project: phoenix_project()]
    end

    test "create initial migration", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts)
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
      [project: phoenix_project()]
    end

    test "use beacon", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts)
      |> assert_has_patch("lib/test_web/router.ex", """
      4 + |  use Beacon.Router
      """)
    end

    test "mount site in router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts)
      |> assert_has_patch("lib/test_web/router.ex", """
      19 + |  scope "/" do
      20 + |    pipe_through [:browser]
      21 + |    beacon_site "/", site: :my_site
      22 + |  end
      """)
    end
  end

  describe "application" do
    setup do
      [project: phoenix_project()]
    end

    test "add beacon child with site config", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts)
      |> assert_has_patch("lib/test/application.ex", """
      20 + |      TestWeb.Endpoint,
      21 + |      {Beacon, [sites: [[site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]]]}
      """)
    end
  end
end
