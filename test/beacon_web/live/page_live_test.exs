defmodule BeaconWeb.Live.PageLiveTest do
  use BeaconWeb.ConnCase, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Beacon.Content

  setup do
    live_data = live_data_fixture(site: :my_site, path: "/home")
    live_data_assign_fixture(live_data: live_data, format: :elixir, key: "vals", value: "[\"first\", \"second\", \"third\"]")

    component_fixture(name: "sample_component")

    layout =
      published_layout_fixture(
        meta_tags: [
          %{"http-equiv" => "refresh", "content" => "300"}
        ],
        resource_links: [
          %{"rel" => "stylesheet", "href" => "print.css", "media" => "print"},
          %{
            "rel" => "preload",
            "href" => "font.woff2",
            "as" => "font",
            "type" => "font/woff2",
            "crossorigin" => "anonymous"
          }
        ]
      )

    page_home =
      page_fixture(
        layout_id: layout.id,
        path: "/home",
        template: """
        <main>
          <h2>Some Values:</h2>
          <%= for val <- @beacon_live_data[:vals] do %>
            <%= my_component("sample_component", val: val) %>
          <% end %>

          <.form :let={f} for={%{}} as={:greeting} phx-submit="hello">
            Name: <%= text_input f, :name %>
            <%= submit "Hello" %>
          </.form>

          <%= if assigns[:message], do: assigns.message %>

          <%= dynamic_helper("upcase", %{name: "test_name"}) %>
        </main>
        """,
        meta_tags: [
          %{"name" => "csrf-token", "content" => "csrf-token-page"},
          %{"name" => "theme-color", "content" => "#3c790a", "media" => "(prefers-color-scheme: dark)"},
          %{"property" => "og:title", "content" => "Beacon"}
        ],
        helpers: [
          page_helper_params()
        ]
      )

    _page_home_form_submit_handler =
      page_event_handler_fixture(%{
        page: page_home,
        name: "hello",
        code: """
        {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
        """
      })

    Content.publish_page(page_home)
    Beacon.Loader.reload_page_module(page_home.site, page_home.id)

    _page_without_meta_tags =
      published_page_fixture(
        layout_id: layout.id,
        path: "/without_meta_tags",
        template: """
        <main>
        </main>
        """,
        meta_tags: nil
      )

    [layout: layout]
  end

  test "live data", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/home")

    assert has_element?(view, "#my-component-first", "first")
    assert has_element?(view, "#my-component-second", "second")
    assert has_element?(view, "#my-component-third", "third")
  end

  describe "meta tags" do
    test "merge layout, page, and site", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      expected =
        ~S"""
        <head>
          <meta name="csrf-token" content=".*"/>
          <meta content="#3c790a" media="\(prefers-color-scheme: dark\)" name="theme-color"/>
          <meta content="Beacon" property="og:title"/>
          <meta content="300" http-equiv="refresh"/>
          <meta charset="utf-8"/>
          <meta content="IE=edge" http-equiv="X-UA-Compatible"/>
          <meta content="width=device-width, initial-scale=1" name="viewport"/>
        """
        |> String.replace("\n", "")
        |> String.replace("  ", "")
        |> Regex.compile!()

      assert html =~ expected
    end

    test "do not overwrite csrf-token", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      refute html =~ "csrf-token-page"
    end

    test "render without meta tags", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/without_meta_tags")
    end

    test "interpolate snippets", %{conn: conn} do
      snippet_helper_fixture(%{
        site: "my_site",
        name: "og_description",
        body: ~S"""
        assigns
        |> get_in(["page", "description"])
        |> String.upcase()
        """
      })

      layout = published_layout_fixture()

      [
        site: "my_site",
        layout_id: layout.id,
        path: "/page/meta-tag",
        title: "my first page",
        description: "my test page",
        meta_tags: [
          %{"property" => "og:description", "content" => "{% helper 'og_description' %}"},
          %{"property" => "og:url", "content" => "http://example.com{{ page.path }}"},
          %{"property" => "og:image", "content" => "{{ live_data.image }}"}
        ]
      ]
      |> published_page_fixture()
      |> Beacon.Repo.preload(:event_handlers)

      live_data = live_data_fixture(path: "/page/meta-tag")
      live_data_assign_fixture(live_data: live_data, format: :text, key: "image", value: "http://img.example.com")

      {:ok, _view, html} = live(conn, "/page/meta-tag")

      expected =
        ~S"""
        <meta content="MY TEST PAGE" property="og:description"/>
        <meta content="http://example.com/page/meta-tag" property="og:url"/>
        <meta content="http://img.example.com" property="og:image"/>
        """
        |> String.replace("\n", "")
        |> String.replace("  ", "")
        |> Regex.compile!()

      assert html =~ expected
    end
  end

  describe "resource links" do
    test "render layout resource links on page head", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~S|<link href="print.css" media="print" rel="stylesheet"/>|
      assert html =~ ~S|<link as="font" crossorigin="anonymous" href="font.woff2" rel="preload" type="font/woff2"/>|
    end

    test "update resource links on layout publish", %{conn: conn, layout: layout} do
      {:ok, layout} = Content.update_layout(layout, %{"resource_links" => [%{"rel" => "stylesheet", "href" => "color.css"}]})
      {:ok, layout} = Content.publish_layout(layout)
      Beacon.Loader.reload_layout_module(layout.site, layout.id)
      {:ok, _view, html} = live(conn, "/home")
      assert html =~ ~S|<link href="color.css" rel="stylesheet"/>|
    end
  end

  describe "render" do
    test "a given path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

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
      assert_raise BeaconWeb.NotFoundError, fn ->
        {:ok, _view, _html} = live(conn, "/no_page_match")
      end
    end

    test "routes to custom live path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/home")

      assert html =~ ~s(phx-socket="/custom_live")
    end
  end

  describe "page title" do
    test "with snippet helper from page", %{conn: conn, layout: layout} do
      published_page_fixture(layout_id: layout.id, title: "{{ page.path }}", path: "/my/:page")
      {:ok, view, _html} = live(conn, "/my/:page")
      assert page_title(view) =~ "/my/:page"
    end

    test "with snippet helper from live data assigns", %{conn: conn, layout: layout} do
      published_page_fixture(layout_id: layout.id, title: "page {{ live_data.test }}", path: "/my/page/:var")
      live_data = live_data_fixture(path: "/my/page/:var")
      live_data_assign_fixture(live_data: live_data, format: :elixir, key: "test", value: "var")

      {:ok, view, _html} = live(conn, "/my/page/foobar")

      assert page_title(view) =~ "page foobar"
    end
  end

  describe "markdown" do
    test "page template", %{conn: conn, layout: layout} do
      live_data_fixture(path: "/markdown")
      published_page_fixture(layout_id: layout.id, format: "markdown", template: "# Title", path: "/markdown")

      {:ok, view, _html} = live(conn, "/markdown")

      assert has_element?(view, "h1", "Title")
    end
  end

  describe "components" do
    test "update should reload the resource", %{conn: conn} do
      component = component_fixture(name: "component_test", body: "component_test_v1")
      layout = published_layout_fixture()

      published_page_fixture(
        path: "/component_test",
        template: """
        <%= my_component("component_test", []) %>
        """,
        layout_id: layout.id
      )

      {:ok, _view, html} = live(conn, "/component_test")

      assert html =~ "component_test_v1"

      Content.update_component(component, %{body: "component_test_v2"})
      Beacon.Loader.reload_components_module(component.site)

      {:ok, _view, html} = live(conn, "/component_test")
      assert html =~ "component_test_v2"
    end
  end
end
