defmodule BeaconWeb.ComponentsTest do
  use BeaconWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Beacon.Fixtures

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  describe "reading_time/1" do
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

    test "SUCCESS: reading_time should show 1 min to read the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")

      assert render(view) =~ "3 min to read"
    end
  end

  describe "featured_pages/1 default" do
    setup context do
      create_page_with_component("""
      <main>
        <BeaconWeb.Components.featured_pages />
      </main>
      """)

      context
    end

    test "SUCCESS: reading_time should show 1 min to read the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")

      assert render(view) =~ "href=\"home\""
    end
  end

  describe "featured_pages/1 with Inner Block" do
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

    test "SUCCESS: reading_time should show 1 min to read the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")

      refute render(view) =~ "href=\"home\""
      assert render(view) =~ "FOO BAR"
    end
  end

  defp create_page_with_component(template) do
    layout = published_layout_fixture()

    published_page_fixture(
      layout_id: layout.id,
      path: "home",
      template: template
    )

    Beacon.Loader.load_components(:my_site)
    Beacon.Loader.load_pages(:my_site)
  end
end
