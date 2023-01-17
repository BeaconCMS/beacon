defmodule BeaconWeb.Live.PageLiveTest do
  use BeaconWeb.ConnCase, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Beacon.Fixtures

  setup_all do
    start_supervised!(@endpoint)
    :ok
  end

  defp create_page(_) do
    stylesheet_fixture()
    component_fixture()
    layout = layout_fixture()

    page =
      page_fixture(
        layout_id: layout.id,
        template: """
        <main>
          <h2>Some Values:</h2>
          <%= for val <- @beacon_live_data[:vals] do %>
            <%= my_component("sample_component", val: val) %>
          <% end %>

          <.form let={f} for={:greeting} phx-submit="hello">
            Name: <%= text_input f, :name %>
            <%= submit "Hello" %>
          </.form>

          <%= if assigns[:message], do: assigns.message %>

          <%= dynamic_helper("upcase", %{name: "test_name"}) %>
        </main>
        """
      )

    page_event_fixture(%{page_id: page.id})
    page_helper_fixture(%{page_id: page.id})

    :ok
  end

  defp create_page_without_meta(_) do
    stylesheet_fixture()
    component_fixture()
    layout = layout_without_meta_fixture()

    page =
      page_without_meta_fixture(
        layout_id: layout.id,
        template: """
        <main>
          <h2>Some Values:</h2>
          <%= for val <- @beacon_live_data[:vals] do %>
            <%= my_component("sample_component", val: val) %>
          <% end %>

          <.form let={f} for={:greeting} phx-submit="hello">
            Name: <%= text_input f, :name %>
            <%= submit "Hello" %>
          </.form>

          <%= if assigns[:message], do: assigns.message %>

          <%= dynamic_helper("upcase", %{name: "test_name"}) %>
        </main>
        """
      )

    page_event_fixture(%{page_id: page.id})
    page_helper_fixture(%{page_id: page.id})

    :ok
  end

  describe "render meta tags" do
    setup [:create_page]

    test "for a layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(<meta name="layout-meta-tag-one" content="value"/>)
      assert html =~ ~s(<meta name="layout-meta-tag-two" content="value"/>)
    end

    test "for a page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(<meta name="home-meta-tag-one" content="value"/>)
      assert html =~ ~s(<meta name="home-meta-tag-two" content="value"/>)
    end
  end

  describe "render no page/layout meta tags" do
    setup [:create_page_without_meta]

    test "", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      refute html =~ ~s(<meta name="home-meta-tag-one" content="value"/>)
      refute html =~ ~s(<meta name="home-meta-tag-two" content="value"/>)
      refute html =~ ~s(<meta name="layout-meta-tag-one" content="value"/>)
      refute html =~ ~s(<meta name="layout-meta-tag-two" content="value"/>)
    end
  end

  describe "render" do
    setup [:create_page]

    test "a given path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ "body {cursor: zoom-in;}"
      assert html =~ "<header>Page header</header>"
      assert html =~ ~s"<main><h2>Some Values:</h2>"
      assert html =~ "<footer>Page footer</footer>"
    end

    test "component", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(<span id="my-component-first">)
      assert html =~ ~s(<span id="my-component-second">)
      assert html =~ ~s(<span id="my-component-third">)
    end

    test "event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")

      assert view
             |> form("form", %{greeting: %{name: "Beacon"}})
             |> render_submit() =~ "Hello Beacon"
    end

    test "helper", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(TEST_NAME)
    end

    test "raise when the given path doesn't exist", %{conn: conn} do
      error_message = """
      Could not call layout_id_for_path for the given path: [\"no_page_match\"].

      Make sure you have created a page for this path. Check Pages.create_page!/2 \
      for more info.\
      """

      assert_raise Beacon.Loader.Error, error_message, fn ->
        {:ok, _view, _html} = live(conn, "/no_page_match")
      end
    end
  end
end
