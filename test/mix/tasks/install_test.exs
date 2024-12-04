defmodule Mix.Tasks.Beacon.InstallTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  setup do
    [project: phoenix_project()]
  end

  test "add :beacon dep into formatter config", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> assert_has_patch(".formatter.exs", """
    7    - |  import_deps: [:ecto, :ecto_sql, :phoenix],
       7 + |  import_deps: [:beacon, :ecto, :ecto_sql, :phoenix],
    """)
  end

  test "replace error html in config formats", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> assert_has_patch("config/config.exs", """
    19    - |    formats: [html: TestWeb.ErrorHTML, json: TestWeb.ErrorJSON],
       19 + |    formats: [html: Beacon.Web.ErrorHTML, json: TestWeb.ErrorJSON],
    """)
  end

  test "add Beacon.Plug to router pipeline", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install")
    |> assert_has_patch("lib/test_web/router.ex", """
      9  9   |    plug(:protect_from_forgery)
     10 10   |    plug(:put_secure_browser_headers)
        11 + |    plug Beacon.Plug
     11 12   |  end
    """)
  end

  test "optionally generates new site", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install", ~w(--site my_site --path /my_site))
    |> assert_has_patch("lib/test_web/router.ex", """
    20 + |  scope "/" do
    21 + |    pipe_through [:browser]
    22 + |    beacon_site "/my_site", site: :my_site
    23 + |  end
    """)
  end
end
