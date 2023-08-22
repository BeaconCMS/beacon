defmodule BeaconWeb.PublishTest do
  use BeaconWeb.ConnCase, async: false

  # import Phoenix.ConnTest
  # import Phoenix.LiveViewTest
  import Beacon.Fixtures
  alias Beacon.Content

  defp start_loader(_) do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  defp create_page(_) do
    stylesheet_fixture()
    layout = published_layout_fixture()
    page = page_fixture(layout_id: layout.id, path: "publish_test")

    Beacon.reload_site(:my_site)

    [layout: layout, page: page]
  end

  describe "publish layout" do
    setup [:start_loader, :create_page]

    test "receive layout_published event", %{layout: %{id: id} = layout} do
      Beacon.PubSub.subscribe_to_layouts(layout.site)
      Content.publish_layout(layout)

      assert_receive {:layout_published, layout}
      assert %{site: :my_site, id: ^id} = layout
    end
  end

  describe "publish page" do
    setup [:start_loader, :create_page]

    test "receive page_published event", %{page: %{id: id} = page} do
      Beacon.PubSub.subscribe_to_pages(page.site)
      Content.publish_page(page)

      assert_receive {:page_published, page}
      assert %{site: :my_site, path: "publish_test", id: ^id} = page
    end

    test "receive page_loaded event", %{page: %{id: id} = page} do
      Beacon.PubSub.subscribe_to_page(page.site, [page.path])
      Content.publish_page(page)

      assert_receive {:page_loaded, page}
      assert %{site: :my_site, path: "publish_test", id: ^id} = page
    end
  end
end
