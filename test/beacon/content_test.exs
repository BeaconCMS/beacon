defmodule Beacon.ContentTest do
  use Beacon.DataCase
  import Beacon.Fixtures
  alias Beacon.Content
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.Page
  alias Beacon.Content.PageEvent
  alias Beacon.PubSub
  alias Beacon.Repo

  describe "layouts" do
    test "create layout should create a created event" do
      Content.create_layout!(%{
        site: "my_site",
        title: "test",
        body: "<p>layout</p>"
      })

      assert %LayoutEvent{event: :created} = Repo.one(LayoutEvent)
    end

    test "publish layout should create a published event" do
      layout = layout_fixture()

      assert {:ok, %Layout{}} = Content.publish_layout(layout)
      assert [_created, %LayoutEvent{event: :published}] = Repo.all(LayoutEvent)
    end

    test "publish layout should create a snapshot" do
      layout = layout_fixture(title: "snapshot test")

      assert {:ok, %Layout{}} = Content.publish_layout(layout)
      assert %LayoutSnapshot{layout: %Layout{title: "snapshot test"}} = Repo.one(LayoutSnapshot)
    end

    test "publish layout should broadcast published event" do
      PubSub.subscribe_layout_published()

      layout = layout_fixture()
      assert {:ok, %Layout{}} = Content.publish_layout(layout)

      assert_received %LayoutEvent{event: :published}
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

  describe "pages" do
    test "create page should create a created event" do
      layout = layout_fixture()

      Content.create_page!(%{
        site: "my_site",
        path: "/",
        template: "<p>page</p>",
        layout_id: layout.id
      })

      assert %PageEvent{event: :created} = Repo.one(PageEvent)
    end

    test "publish page should create a published event" do
      page = page_fixture()

      assert {:ok, %Page{}} = Content.publish_page(page)
      assert [_created, %PageEvent{event: :published}] = Repo.all(PageEvent)
    end

    # test "publish page should create a snapshot" do

    test "publish page should broadcast published event" do
      PubSub.subscribe_page_published()

      page = page_fixture()
      assert {:ok, %Page{}} = Content.publish_page(page)

      assert_received %PageEvent{event: :published}
    end

    # test "list published pages" do
  end
end
