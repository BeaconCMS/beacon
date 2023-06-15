defmodule Beacon.ContentTest do
  use Beacon.DataCase, async: true
  import Beacon.Fixtures
  alias Beacon.Content
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Repo

  defp start_loader(_) do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  describe "layouts" do
    setup [:start_loader]

    test "publish layout should create a published event" do
      layout = layout_fixture()

      assert {:ok, %Layout{}} = Content.publish_layout(layout)
      assert %LayoutEvent{event: :published} = Repo.one(LayoutEvent)
    end

    test "publish layout should create a snapshot" do
      layout = layout_fixture(title: "snapshot test")

      assert {:ok, %Layout{}} = Content.publish_layout(layout)
      assert %LayoutSnapshot{layout: %Layout{title: "snapshot test"}} = Repo.one(LayoutSnapshot)
    end

    test "list published layouts" do
      # publish layout_a twice
      layout_a = layout_fixture(title: "layout_a v1")
      {:ok, layout_a} = Content.publish_layout(layout_a)
      {:ok, layout_a} = Content.update_layout(layout_a, %{"title" => "layout_a v2"})
      {:ok, _layout_a} = Content.publish_layout(layout_a)

      # do not publish layout_b
      _layout_b = layout_fixture(title: "layout_b v1")

      assert [%Layout{title: "layout_a v2"}] = Content.list_published_layouts(:my_site)
    end
  end
end
