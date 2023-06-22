defmodule Beacon.LoaderTest do
  use BeaconWeb.ConnCase, async: false

  import Beacon.Fixtures
  alias Beacon.Loader

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  test "reload_module! validates ast" do
    ast =
      quote do
        defmodule Foo.Bar do
          def
        end
      end

    assert_raise Beacon.LoaderError, ~r/failed to load module Foo.Bar/, fn ->
      Loader.reload_module!(Foo.Bar, ast, "custom file")
    end
  end

  describe "resources loading" do
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
          path: "/loader_test",
          template: """
          <main>
            <div>page_v1</div>
            <%= my_component("component_loader_test", %{}) %>
          </main>
          """
        )

      Beacon.Content.publish_layout(layout)
      Beacon.Content.publish_page(page)

      Beacon.reload_site(:my_site)

      [layout: layout, page: page]
    end

    setup [:create_page]

    test "reload page and dependencies", %{conn: conn, layout: layout, page: page} do
      {:ok, _view, html} = live(conn, "/loader_test")
      assert html =~ "component_v1"
      assert html =~ "layout_v1"
      assert html =~ "page_v1"

      Beacon.Repo.update_all(Beacon.Components.Component, set: [body: "<header>component_v2</header>"])

      {:ok, layout} =
        Beacon.Content.update_layout(layout, %{
          body: """
          <header>layout_v2</header>
          <%= @inner_content %>
          """
        })

      {:ok, _layout} = Beacon.Content.publish_layout(layout)

      {:ok, page} =
        Beacon.Content.update_page(page, %{
          template: """
          <main>
            <div>page_v2</div>
            <%= my_component("component_loader_test", %{}) %>
          </main>
          """
        })

      {:ok, page} = Beacon.Content.publish_page(page)

      Beacon.Loader.load_page(page)

      {:ok, _view, html} = live(conn, "/loader_test")
      assert html =~ "component_v2"
      assert html =~ "layout_v2"
      assert html =~ "page_v2"
    end

    test "unload", %{page: page} do
      module = Beacon.Loader.page_module_for_site(page.site, page.id)
      assert Keyword.has_key?(module.__info__(:functions), :page_assigns)

      Beacon.Loader.unload_page(page)

      assert_raise UndefinedFunctionError, fn ->
        module.__info__(:functions)
      end
    end
  end
end
