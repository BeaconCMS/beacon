defmodule Beacon.LoaderTest do
  use BeaconWeb.ConnCase, async: false

  import Beacon.Fixtures
  alias Beacon.Loader

  test "reload_module! validates ast" do
    ast =
      quote do
        defmodule Foo.Bar do
          def
        end
      end

    assert_raise Beacon.LoaderError, ~r/Failed to load module Foo.Bar, got: custom file: undefined function def/, fn ->
      Loader.reload_module!(Foo.Bar, ast, "custom file")
    end
  end

  describe "page reload" do
    defp start_loader(_) do
      start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
      :ok
    end

    defp create_page(_) do
      stylesheet_fixture()

      layout =
        layout_fixture(
          body: """
          <header>layout_v1</header>
          <%= @inner_content %>
          """
        )

      component_fixture(
        name: "component_loader_test",
        body: """
        <header>component_v1</header>
        """
      )

      page =
        page_fixture(
          layout_id: layout.id,
          path: "home",
          template: """
          <main>
            <div>page_v1</div>
            <%= my_component("component_loader_test", %{}) %>
          </main>
          """
        )

      Beacon.reload_site(:my_site)

      [page: page]
    end

    setup [:start_loader, :create_page]

    test "reload page and dependencies", %{conn: conn, page: page} do
      {:ok, _view, html} = live(conn, "/home")
      assert html =~ "component_v1"
      assert html =~ "layout_v1"
      assert html =~ "page_v1"

      Beacon.Repo.update_all(Beacon.Components.Component, set: [body: "<header>component_v2</header>"])

      Beacon.Repo.update_all(Beacon.Layouts.Layout,
        set: [
          body: """
            <header>layout_v2</header>
            <%= @inner_content %>
          """
        ]
      )

      page_v2_template = """
            <main>
              <div>page_v2</div>
              <%= my_component("component_loader_test", %{}) %>
            </main>
      """

      Beacon.Repo.update_all(Beacon.Pages.Page, set: [template: page_v2_template, pending_template: page_v2_template])
      page = Beacon.Repo.get_by(Beacon.Pages.Page, path: page.path)

      Beacon.reload_page(page)

      {:ok, _view, html} = live(conn, "/home")
      assert html =~ "component_v2"
      assert html =~ "layout_v2"
      assert html =~ "page_v2"
    end
  end
end
