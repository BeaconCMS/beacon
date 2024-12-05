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

  test "optionally generates new site", %{project: project} do
    project
    |> Igniter.compose_task("beacon.install", ~w(--site my_site --path /my_site))
    |> assert_has_patch("lib/test_web/router.ex", """
    24 + |    pipe_through [:browser, :beacon]
    25 + |    beacon_site "/my_site", site: :my_site
    """)
  end
end
