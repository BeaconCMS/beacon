defmodule BeaconWeb.ComponentsTest do
  use BeaconWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Beacon.Fixtures

  describe "reading_time" do
    setup context do
      create_page_with_component("""
      <main>
        <p>
        #{Faker.Lorem.words(901) |> Enum.join(" ")}
        </p>
        <BeaconWeb.Components.reading_time /> min to read
      </main>
      """)

      context
    end

    test "displays the estimated time to read the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")
      assert render(view) =~ "3 min to read"
    end
  end

  describe "featured_pages" do
    setup context do
      create_page_with_component("""
      <main>
      <BeaconWeb.Components.featured_pages :let={_page} pages={Beacon.Content.list_pages(Process.get(:__beacon_site__), per_page: 3)}>
          FOO BAR
      </BeaconWeb.Components.featured_pages>
      </main>
      """)

      context
    end

    test "displays feature page inner block content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")
      assert render(view) =~ "FOO BAR"
    end
  end

  defp create_page_with_component(template) do
    Beacon.Loader.fetch_components_module(:my_site)

    layout = published_layout_fixture()

    published_page_fixture(
      layout_id: layout.id,
      path: "/home",
      template: template
    )
  end
end
