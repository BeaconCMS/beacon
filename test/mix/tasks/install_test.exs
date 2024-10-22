defmodule Mix.Tasks.Beacon.InstallTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  setup do
    [igniter: phoenix_project()]
  end

  test "add :beacon dep into formatter", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("beacon.install", ["--yes"])
    |> assert_has_patch(".formatter.exs", """
    2   - |  import_deps: [:ecto, :ecto_sql, :phoenix],
      2 + |  import_deps: [:beacon, :ecto, :ecto_sql, :phoenix],
    """)
  end

  test "add error html into config formats", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("beacon.install", ["--yes"])
    |> assert_has_patch("config/config.exs", """
    19    - |    formats: [html: TestWeb.ErrorHTML, json: TestWeb.ErrorJSON],
       19 + |    formats: [html: Beacon.Web.ErrorHTML, json: TestWeb.ErrorJSON],
    """)
  end
end
