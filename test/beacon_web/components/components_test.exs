defmodule BeaconWeb.ComponentsTest do
  use BeaconWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Beacon.Fixtures

  describe "reading_time" do
    test "displays the estimated time to read the page", %{conn: conn} do
      create_page_with_component("/reading_time", "reading_time", ~S"""
      <main>
        <p>word word word</p>
        <p>word word word</p>
        <.reading_time site={:my_site} path="/reading_time" words_per_minute={1} /> min to read
      </main>
      """)

      {:ok, view, _html} = live(conn, "/reading_time")
      assert render(view) =~ "8 min to read"
    end
  end

  describe "embed" do
    test "displays youtube video", %{conn: conn} do
      create_page_with_component("/youtube_video", "embedded", """
      <main>
        <.embedded url="https://www.youtube.com/watch?v=giYbq4HmfGA" />
      </main>
      """)

      {:ok, view, _html} = live(conn, "/youtube_video")
      assert has_element?(view, ~s(iframe[src*="https://www.youtube.com/embed/giYbq4HmfGA?feature=oembed"]))
    end
  end

  describe "featured_pages" do
    test "render inner slot", %{conn: conn} do
      create_component("page_link")

      create_page_with_component("/featured_pages", "featured_pages", """
      <main>
      <.featured_pages :let={_page} site={:my_site}>
          __FEATURED_PAGE__
      </.featured_pages>
      </main>
      """)

      {:ok, view, _html} = live(conn, "/featured_pages")
      assert render(view) =~ "__FEATURED_PAGE__"
    end
  end

  defp create_component(name) do
    Beacon.Content.blueprint_components()
    |> Enum.find(&(&1.name == name))
    |> component_fixture()
  end

  defp create_page_with_component(path, component_name, template) do
    attrs = Enum.find(Beacon.Content.blueprint_components(), &(&1.name == component_name))
    component_fixture(attrs)

    layout = published_layout_fixture()

    page =
      published_page_fixture(
        layout_id: layout.id,
        path: path,
        template: template
      )

    Beacon.Loader.reload_live_data_module(:my_site)
    Beacon.Loader.reload_components_module(:my_site)
    Beacon.Loader.reload_layout_module(layout.site, layout.id)
    Beacon.Loader.reload_page_module(page.site, page.id)
  end
end
