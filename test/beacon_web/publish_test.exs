defmodule BeaconWeb.PublishTest do
  use BeaconWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Beacon.Fixtures
  alias Beacon.Pages

  defp start_loader(_) do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  defp create_page(_) do
    stylesheet_fixture()

    layout = layout_fixture()

    page =
      page_fixture(
        layout_id: layout.id,
        path: "publish_test",
        template: """
        <main>
          <h1 class="text-red-500">title</h1>
        </main>
        """
      )

    Beacon.reload_site(:my_site)

    [page: page]
  end

  describe "publish" do
    setup [:start_loader, :create_page]

    test "update template", %{conn: conn, page: page} do
      {:ok, view, html} = live(conn, "/publish_test")

      assert html =~ ~s|<h1 class="text-red-500">title</h1>|

      params = %{
        "pending_template" => ~s|<main><h1 class="text-blue-100">title</h1></main>|,
        "pending_layout_id" => page.layout_id
      }

      assert {:ok, page} =
               Pages.update_page_pending(
                 page,
                 params["pending_template"],
                 params["pending_layout_id"],
                 params
               )

      assert {:ok, _page} = Pages.publish_page(page)

      html = render(view)

      assert html =~ ~s|<h1 class="text-blue-100">title</h1>|
    end
  end
end
