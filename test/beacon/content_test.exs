defmodule Beacon.ContentTest do
  use Beacon.DataCase

  import Beacon.Fixtures

  alias Beacon.Content
  alias Beacon.Content.Component
  alias Beacon.Content.ErrorPage
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.LiveData
  alias Beacon.Content.Page
  alias Beacon.Content.PageEvent
  alias Beacon.Content.PageEventHandler
  alias Beacon.Content.PageSnapshot
  alias Beacon.Content.PageVariant
  alias Beacon.Repo
  alias Ecto.Changeset

  describe "layouts" do
    test "broadcasts published event" do
      %{site: site, id: id} = layout = layout_fixture(site: "booted")
      :ok = Beacon.PubSub.subscribe_to_layouts(site)
      Content.publish_layout(layout)
      assert_receive {:layout_published, %{site: ^site, id: ^id}}
    end

    test "create layout should create a created event" do
      Content.create_layout!(%{
        site: "my_site",
        title: "test",
        template: "<p>layout</p>"
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

    test "list_layout_events" do
      layout = layout_fixture()
      Content.publish_layout(layout)

      assert [
               %LayoutEvent{event: :published, snapshot: %LayoutSnapshot{}},
               %LayoutEvent{event: :created, snapshot: nil}
             ] = Content.list_layout_events(layout.site, layout.id)
    end

    test "get_latest_layout_event" do
      layout = layout_fixture()
      assert %LayoutEvent{event: :created} = Content.get_latest_layout_event(layout.site, layout.id)

      Content.publish_layout(layout)
      assert %LayoutEvent{event: :published} = Content.get_latest_layout_event(layout.site, layout.id)
    end

    test "validate body heex on create" do
      assert {:error, %Ecto.Changeset{errors: [template: {"invalid", [compilation_error: compilation_error]}]}} =
               Content.create_layout(%{site: :my_site, title: "test", template: "<div"})

      assert compilation_error =~ "expected closing `>`"
    end

    test "validate body heex on update" do
      layout = layout_fixture()

      assert {:error, %Ecto.Changeset{errors: [template: {"invalid", [compilation_error: compilation_error]}]}} =
               Content.update_layout(layout, %{template: "<div"})

      assert compilation_error =~ "expected closing `>`"
    end

    test "page and per_page" do
      layout_fixture(title: "first")
      layout_fixture(title: "second")

      assert [%Layout{title: "first"}] = Content.list_layouts(:my_site, per_page: 1, page: 1, sort: :title)
      assert [%Layout{title: "second"}] = Content.list_layouts(:my_site, per_page: 1, page: 2, sort: :title)
      assert [] = Content.list_layouts(:my_site, per_page: 2, page: 2, sort: :title)
    end

    test "no layouts return 0" do
      assert Content.count_layouts(:my_site) == 0
    end

    test "filter by title" do
      layout_fixture(title: "first")
      layout_fixture(title: "second")

      assert Content.count_layouts(:my_site, query: "first") == 1
      assert Content.count_layouts(:my_site, query: "second") == 1
      assert Content.count_layouts(:my_site, query: "third") == 0
    end
  end

  describe "pages" do
    test "broadcasts published event" do
      %{site: site, id: id} = page = page_fixture(site: "booted")
      :ok = Beacon.PubSub.subscribe_to_pages(site)
      Content.publish_page(page)
      assert_receive {:page_published, %{site: ^site, id: ^id}}
    end

    test "broadcasts loaded event" do
      %{site: site, id: id, path: path} = published_page_fixture(site: "booted")
      :ok = Beacon.PubSub.subscribe_to_page(site, path)
      Beacon.Loader.reload_page_module(site, id)
      assert_receive {:page_loaded, %{site: ^site, id: ^id}}
    end

    test "broadcasts unpublished event" do
      %{site: site, id: id, path: path} = page = published_page_fixture(site: "booted")
      :ok = Beacon.PubSub.subscribe_to_pages(site)
      assert {:ok, _} = Content.unpublish_page(page)
      assert_receive {:page_unpublished, %{site: ^site, id: ^id, path: ^path}}
    end

    test "count pages" do
      page = page_fixture(title: "title_a")

      assert Content.count_pages(page.site) == 1
      assert Content.count_pages(page.site, query: "title_a") == 1
      assert Content.count_pages(page.site, query: "title_b") == 0
    end

    test "validate template heex on create" do
      layout = layout_fixture()

      assert {:error, %Ecto.Changeset{errors: [template: {"invalid", [compilation_error: compilation_error]}]}} =
               Content.create_page(%{site: :my_site, path: "/", title: "home", layout_id: layout.id, template: "<div"})

      assert compilation_error =~ "expected closing `>`"
    end

    test "validate template heex on update" do
      page = page_fixture()

      assert {:error, %Ecto.Changeset{errors: [template: {"invalid", [compilation_error: compilation_error]}]}} =
               Content.update_page(page, %{template: "<div"})

      assert compilation_error =~ "expected closing `>`"
    end

    test "create page should create a created event" do
      Content.create_page!(%{
        site: "my_site",
        path: "/",
        title: "home",
        template: "<p>page</p>",
        layout_id: layout_fixture().id
      })

      assert %PageEvent{event: :created} = Repo.one(PageEvent)
    end

    test "create page includes default meta tags" do
      page =
        Content.create_page!(%{
          site: "default_meta_tags_test",
          path: "/",
          title: "home",
          template: "<p>page</p>",
          layout_id: layout_fixture().id
        })

      assert page.meta_tags == [%{"name" => "foo", "content" => "bar"}]
    end

    test "update page should validate invalid templates" do
      page = page_fixture()

      assert {:error, %Ecto.Changeset{errors: [template: {"invalid", [compilation_error: compilation_error]}], valid?: false}} =
               Content.update_page(page, %{"template" => "<div>invalid</span>"})

      assert compilation_error =~ "unmatched closing tag"
    end

    test "publish page should create a published event" do
      page = page_fixture()

      assert {:ok, %Page{}} = Content.publish_page(page)
      assert [_created, %PageEvent{event: :published}] = Repo.all(PageEvent)
    end

    test "publish page should create a snapshot" do
      page = page_fixture(title: "snapshot test")

      assert {:ok, %Page{}} = Content.publish_page(page)
      assert %PageSnapshot{page: %Page{title: "snapshot test"}} = Repo.one(PageSnapshot)
    end

    test "list_published_pages" do
      # publish page_a twice
      page_a = page_fixture(path: "/a", title: "page_a v1")
      {:ok, page_a} = Content.publish_page(page_a)
      {:ok, page_a} = Content.update_page(page_a, %{"title" => "page_a v2"})
      {:ok, _page_a} = Content.publish_page(page_a)

      # publish and unpublish page_b
      page_b = page_fixture(path: "/b", title: "page_b v1")
      {:ok, page_b} = Content.publish_page(page_b)
      {:ok, _page_b} = Content.unpublish_page(page_b)

      # do not publish page_c
      _page_c = page_fixture(path: "/c", title: "page_c v1")

      assert [%Page{title: "page_a v2"}] = Content.list_published_pages(:my_site)
    end

    test "list_published_pages with same inserted_at missing usec" do
      page = page_fixture(path: "/d", title: "page v1")
      Beacon.Repo.query!("UPDATE beacon_page_events SET inserted_at = '2020-01-01'", [])
      Beacon.Repo.query!("UPDATE beacon_page_snapshots SET inserted_at = '2020-01-01'", [])

      assert Content.list_published_pages(:my_site) == []

      {:ok, _page} = Content.publish_page(page)
      Beacon.Repo.query!("UPDATE beacon_page_events SET inserted_at = '2020-01-01'", [])
      Beacon.Repo.query!("UPDATE beacon_page_snapshots SET inserted_at = '2020-01-01'", [])

      assert [%Page{title: "page v1"}] = Content.list_published_pages(:my_site)
    end

    test "list_page_events" do
      page = page_fixture()
      Content.publish_page(page)
      Content.unpublish_page(page)

      assert [
               %PageEvent{event: :unpublished, snapshot: nil},
               %PageEvent{event: :published, snapshot: %PageSnapshot{}},
               %PageEvent{event: :created, snapshot: nil}
             ] = Content.list_page_events(page.site, page.id)
    end

    test "get_latest_page_event" do
      page = page_fixture()
      assert %PageEvent{event: :created} = Content.get_latest_page_event(page.site, page.id)

      Content.publish_page(page)
      assert %PageEvent{event: :published} = Content.get_latest_page_event(page.site, page.id)

      Content.unpublish_page(page)
      assert %PageEvent{event: :unpublished} = Content.get_latest_page_event(page.site, page.id)

      Content.publish_page(page)
      assert %PageEvent{event: :published} = Content.get_latest_page_event(page.site, page.id)
    end

    test "lifecycle after_create_page" do
      layout = layout_fixture(site: :lifecycle_test)

      Content.create_page!(%{
        site: "lifecycle_test",
        path: "/",
        title: "home",
        template: "<p>page</p>",
        layout_id: layout.id
      })

      assert_receive :lifecycle_after_create_page
    end

    test "lifecycle after_update_page" do
      layout = layout_fixture(site: :lifecycle_test)

      page =
        Content.create_page!(%{
          site: "lifecycle_test",
          path: "/",
          title: "home",
          template: "<p>page</p>",
          layout_id: layout.id
        })

      Content.update_page(page, %{template: "<p>page updated</p>"})

      assert_receive :lifecycle_after_create_page
      assert_receive :lifecycle_after_update_page
    end

    test "lifecycle after_publish_page" do
      layout = layout_fixture(site: :lifecycle_test)

      page =
        Content.create_page!(%{
          site: "lifecycle_test",
          path: "/",
          title: "home",
          template: "<p>page</p>",
          layout_id: layout.id
        })

      Content.publish_page(page)

      assert %{title: "updated after publish page"} = Beacon.Content.get_page(page.id)
    end

    test "save raw_schema" do
      layout = layout_fixture(site: :raw_schema_test)

      assert %Page{raw_schema: [%{"foo" => "bar"}]} =
               Content.create_page!(%{
                 site: "my_site",
                 path: "/",
                 title: "home",
                 template: "<p>page</p>",
                 layout_id: layout.id,
                 raw_schema: [%{"foo" => "bar"}]
               })
    end

    test "update raw_schema" do
      layout = layout_fixture(site: :raw_schema_test)

      page =
        Content.create_page!(%{
          site: "my_site",
          path: "/",
          title: "home",
          template: "<p>page</p>",
          layout_id: layout.id,
          raw_schema: [%{"foo" => "bar"}]
        })

      assert {:ok, %Page{raw_schema: [%{"@type" => "BlogPosting"}]}} = Content.update_page(page, %{"raw_schema" => [%{"@type" => "BlogPosting"}]})
    end

    test "validate raw_schema" do
      layout = layout_fixture(site: :raw_schema_test)

      assert {:error,
              %{
                errors: [
                  raw_schema: {"expected a list of map or a map, got: [nil]", [type: Beacon.Types.JsonArrayMap, validation: :cast]}
                ]
              }} =
               Content.create_page(%{
                 site: "my_site",
                 path: "/",
                 title: "home",
                 template: "<p>page</p>",
                 layout_id: layout.id,
                 raw_schema: [nil]
               })
    end
  end

  describe "stylesheets" do
    test "create broadcasts updated content event" do
      :ok = Beacon.PubSub.subscribe_to_content(:booted)
      %{site: site} = stylesheet_fixture(site: "booted")
      assert_receive {:content_updated, :stylesheet, %{site: ^site}}
    end

    test "update broadcasts updated content event" do
      %{site: site} = stylesheet = stylesheet_fixture(site: "booted")
      :ok = Beacon.PubSub.subscribe_to_content(site)
      Content.update_stylesheet(stylesheet, %{body: "/* test */"})
      assert_receive {:content_updated, :stylesheet, %{site: ^site}}
    end
  end

  describe "snippets" do
    test "create broadcasts updated content event" do
      :ok = Beacon.PubSub.subscribe_to_content(:booted)
      %{site: site} = snippet_helper_fixture(site: "booted")
      assert_receive {:content_updated, :snippet_helper, %{site: ^site}}
    end

    test "assigns" do
      assert Content.render_snippet(
               "page title is {{ page.title }}",
               %{page: %{title: "test"}, live_data: %{}}
             ) == {:ok, "page title is test"}

      assert Content.render_snippet(
               "author.id is {{ page.extra.author.id }}",
               %{page: %{extra: %{"author" => %{"id" => 1}}}, live_data: %{}}
             ) == {:ok, "author.id is 1"}
    end

    test "with live data" do
      assert Content.render_snippet(
               "page title is {{ live_data.foo }}",
               %{page: %{}, live_data: %{foo: "foobar"}}
             ) == {:ok, "page title is foobar"}

      assert Content.render_snippet(
               "foo, bar, baz... {{ live_data.foo.bar.baz }}",
               %{page: %{}, live_data: %{foo: %{bar: %{baz: "bong"}}}}
             ) == {:ok, "foo, bar, baz... bong"}
    end

    test "render helper" do
      snippet_helper_fixture(
        site: "my_site",
        name: "author_name",
        body:
          String.trim(~S"""
          author_id = get_in(assigns, ["page", "extra", "author_id"])
          "test_#{author_id}"
          """)
      )

      assert Content.render_snippet(
               "author name is {% helper 'author_name' %}",
               %{page: %{site: "my_site", extra: %{"author_id" => 1}}, live_data: %{}}
             ) == {:ok, "author name is test_1"}
    end
  end

  describe "variants" do
    test "create variant OK" do
      page = page_fixture(%{format: :heex})
      attrs = %{name: "Foo", weight: 3, template: "<div>Bar</div>"}

      assert {:ok, %Page{variants: [variant]}} = Content.create_variant_for_page(page, attrs)
      assert %PageVariant{name: "Foo", weight: 3, template: "<div>Bar</div>"} = variant
    end

    test "create triggers after_update_page lifecycle" do
      page = page_fixture(site: :lifecycle_test)
      attrs = %{name: "Foo", weight: 3, template: "<div>Bar</div>"}

      {:ok, %Page{}} = Content.create_variant_for_page(page, attrs)

      assert_receive :lifecycle_after_update_page
    end

    test "create variant should validate invalid templates" do
      page = page_fixture(%{format: :heex})
      attrs = %{name: "Changed Name", weight: 99, template: "<div>invalid</span>"}

      assert {:error, %Ecto.Changeset{errors: [template: {"invalid", [compilation_error: error]}], valid?: false}} =
               Content.create_variant_for_page(page, attrs)

      assert error =~ "unmatched closing tag"
    end

    test "update variant OK" do
      page = page_fixture(%{format: :heex})
      variant = page_variant_fixture(%{page: page})
      attrs = %{name: "Changed Name", weight: 99, template: "<div>changed</div>"}

      assert {:ok, %Page{variants: [updated_variant]}} = Content.update_variant_for_page(page, variant, attrs)
      assert %PageVariant{name: "Changed Name", weight: 99, template: "<div>changed</div>"} = updated_variant
    end

    test "update triggers after_update_page lifecycle" do
      page = page_fixture(site: :lifecycle_test)
      variant = page_variant_fixture(%{page: page})

      {:ok, %Page{}} = Content.update_variant_for_page(page, variant, %{name: "Changed"})

      assert_receive :lifecycle_after_update_page
    end

    test "update variant should validate invalid templates" do
      page = page_fixture(%{format: :heex})
      variant = page_variant_fixture(%{page: page})
      attrs = %{name: "Changed Name", weight: 99, template: "<div>invalid</span>"}

      assert {:error, %Ecto.Changeset{errors: [template: {"invalid", [compilation_error: error]}], valid?: false}} =
               Content.update_variant_for_page(page, variant, attrs)

      assert error =~ "unmatched closing tag"
    end

    test "update variant should validate total weight of all variants" do
      page = page_fixture(%{format: :heex})
      _variant_1 = page_variant_fixture(%{page: page, weight: 99})
      variant_2 = page_variant_fixture(%{page: page, weight: 0})

      assert {:error, %Ecto.Changeset{errors: [weight: {"total weights cannot exceed 100", []}], valid?: false}} =
               Content.update_variant_for_page(page, variant_2, %{weight: 2})

      assert {:ok, %Page{}} = Content.update_variant_for_page(page, variant_2, %{weight: 1})
    end

    test "update variant should not validate total weight if unchanged" do
      page = page_fixture(%{format: :heex})
      variant_1 = page_variant_fixture(%{page: page, weight: 99})
      _variant_2 = page_variant_fixture(%{page: page, weight: 98})

      assert {:ok, %Page{}} = Content.update_variant_for_page(page, variant_1, %{name: "Foo"})
    end

    test "delete variant OK" do
      page = page_fixture(%{format: :heex})
      variant_1 = page_variant_fixture(%{page: page})
      variant_2 = page_variant_fixture(%{page: page})

      assert {:ok, %Page{variants: [^variant_2]}} = Content.delete_variant_from_page(page, variant_1)
      assert {:ok, %Page{variants: []}} = Content.delete_variant_from_page(page, variant_2)
    end

    test "delete triggers after_update_page lifecycle" do
      page = page_fixture(site: :lifecycle_test)
      variant = page_variant_fixture(%{page: page})

      {:ok, %Page{}} = Content.delete_variant_from_page(page, variant)

      assert_receive :lifecycle_after_update_page
    end
  end

  describe "event_handlers" do
    test "create event handler OK" do
      page = page_fixture()
      attrs = %{name: "Foo", code: "{:noreply, socket}"}

      assert {:ok, %Page{event_handlers: [event_handler]}} = Content.create_event_handler_for_page(page, attrs)
      assert %PageEventHandler{name: "Foo", code: "{:noreply, socket}"} = event_handler
    end

    test "create triggers after_update_page lifecycle" do
      page = page_fixture(site: :lifecycle_test)
      attrs = %{name: "Foo", code: "{:noreply, socket}"}

      {:ok, %Page{}} = Content.create_event_handler_for_page(page, attrs)

      assert_receive :lifecycle_after_update_page
    end

    test "create validates elixir code" do
      page = page_fixture(%{format: :heex})

      attrs = %{name: "test", code: "[1)"}
      assert {:error, %{errors: [error]}} = Content.create_event_handler_for_page(page, attrs)
      {:code, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected token: )"

      attrs = %{name: "test", code: "if true, do false"}
      assert {:error, %{errors: [error]}} = Content.create_event_handler_for_page(page, attrs)
      {:code, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected reserved word: do"

      code = ~S|
      id = String.to_integer(event_params["id"])
      res = if id < 100, do: "less" <> "than", else: "100"
      {:noreply, assign(socket, res: res)}
      |

      attrs = %{name: "test", code: code}
      assert {:ok, _} = Content.create_event_handler_for_page(page, attrs)
    end

    test "update event handler OK" do
      page = page_fixture(%{format: :heex})
      event_handler = page_event_handler_fixture(%{page: page})
      attrs = %{name: "Changed Name", code: "{:noreply, assign(socket, foo: :bar)}"}

      assert {:ok, %Page{event_handlers: [updated_event_handler]}} = Content.update_event_handler_for_page(page, event_handler, attrs)
      assert %PageEventHandler{name: "Changed Name", code: "{:noreply, assign(socket, foo: :bar)}"} = updated_event_handler
    end

    test "update triggers after_update_page lifecycle" do
      page = page_fixture(site: :lifecycle_test)
      event_handler = page_event_handler_fixture(%{page: page})

      {:ok, %Page{}} = Content.update_event_handler_for_page(page, event_handler, %{name: "Changed"})

      assert_receive :lifecycle_after_update_page
    end

    test "update validates elixir code" do
      page = page_fixture(%{format: :heex})
      page_event_handler = page_event_handler_fixture(%{page: page})

      attrs = %{code: "[1)"}
      assert {:error, %{errors: [error]}} = Content.update_event_handler_for_page(page, page_event_handler, attrs)
      {:code, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected token: )"

      attrs = %{code: "if true, do false"}
      assert {:error, %{errors: [error]}} = Content.update_event_handler_for_page(page, page_event_handler, attrs)
      {:code, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected reserved word: do"

      code = ~S|
      id = String.to_integer(event_params["id"])
      res = if id < 100, do: "less" <> "than", else: "100"
      {:noreply, assign(socket, res: res)}
      |

      attrs = %{code: code}
      assert {:ok, _} = Content.update_event_handler_for_page(page, page_event_handler, attrs)
    end

    test "delete event handler OK" do
      page = page_fixture(%{format: :heex})
      event_handler_1 = page_event_handler_fixture(%{page: page})
      event_handler_2 = page_event_handler_fixture(%{page: page})

      assert {:ok, %Page{event_handlers: [^event_handler_2]}} = Content.delete_event_handler_from_page(page, event_handler_1)
      assert {:ok, %Page{event_handlers: []}} = Content.delete_event_handler_from_page(page, event_handler_2)
    end

    test "delete triggers after_update_page lifecycle" do
      page = page_fixture(site: :lifecycle_test)
      event_handler = page_event_handler_fixture(%{page: page})

      {:ok, %Page{}} = Content.delete_event_handler_from_page(page, event_handler)

      assert_receive :lifecycle_after_update_page
    end
  end

  describe "error_pages" do
    test "create broadcasts updated content event" do
      :ok = Beacon.PubSub.subscribe_to_content(:booted)
      %{site: site} = error_page_fixture(site: "booted")
      assert_receive {:content_updated, :error_page, %{site: ^site}}
    end

    test "update broadcasts updated content event" do
      %{site: site} = error_page = error_page_fixture(site: "booted")
      :ok = Beacon.PubSub.subscribe_to_content(site)
      Content.update_error_page(error_page, %{template: "test"})
      assert_receive {:content_updated, :error_page, %{site: ^site}}
    end

    test "get_error_page/2" do
      error_page = error_page_fixture(%{site: :my_site, status: 404})
      _other = error_page_fixture(%{site: :my_site, status: 400})

      assert ^error_page = Content.get_error_page(:my_site, 404)
    end

    test "create_error_page/1 OK" do
      %{id: layout_id} = layout_fixture()
      attrs = %{site: :my_site, status: 400, template: "Oops!", layout_id: layout_id}

      assert {:ok, %ErrorPage{} = error_page} = Content.create_error_page(attrs)
      assert %{site: :my_site, status: 400, template: "Oops!", layout_id: ^layout_id} = error_page
    end

    test "create_error_page/1 ERROR (duplicate)" do
      error_page = error_page_fixture()
      bad_attrs = %{site: error_page.site, status: error_page.status, template: "Error", layout_id: layout_fixture().id}

      assert {:error, %Changeset{errors: errors}} = Content.create_error_page(bad_attrs)
      assert [{:status, {"has already been taken", [constraint: :unique, constraint_name: "beacon_error_pages_status_site_index"]}}] = errors
    end

    test "update_error_page/2" do
      error_page = error_page_fixture()
      assert {:ok, %ErrorPage{template: "Changed"}} = Content.update_error_page(error_page, %{template: "Changed"})
    end

    test "delete_error_page/1" do
      error_page = error_page_fixture()
      assert {:ok, %ErrorPage{__meta__: %{state: :deleted}}} = Content.delete_error_page(error_page)
    end
  end

  describe "components" do
    test "create broadcasts updated content event" do
      :ok = Beacon.PubSub.subscribe_to_content(:booted)
      %{site: site} = component_fixture(site: "booted")
      assert_receive {:content_updated, :component, %{site: ^site}}
    end

    test "update broadcasts updated content event" do
      %{site: site} = component = component_fixture(site: "booted")
      :ok = Beacon.PubSub.subscribe_to_content(site)
      Content.update_component(component, %{body: "<div>test</div>"})
      assert_receive {:content_updated, :component, %{site: ^site}}
    end

    test "validate template heex on create" do
      assert {:error, %Ecto.Changeset{errors: [body: {"invalid", [compilation_error: compilation_error]}]}} =
               Content.create_component(%{site: :my_site, name: "test", body: "<div"})

      assert compilation_error =~ "expected closing `>`"
    end

    test "validate template heex on update" do
      component = component_fixture()

      assert {:error, %Ecto.Changeset{errors: [body: {"invalid", [compilation_error: compilation_error]}]}} =
               Content.update_component(component, %{body: "<div"})

      assert compilation_error =~ "expected closing `>`"
    end

    test "list components" do
      component_a = component_fixture(name: "component_a")
      component_b = component_fixture(name: "component_b")

      components = Content.list_components(component_b.site, query: "_b")

      assert Enum.member?(components, component_b)
      refute Enum.member?(components, component_a)
    end

    test "update_component" do
      component = component_fixture(name: "new_component", body: "old_body")
      assert {:ok, %Component{body: "new_body"}} = Content.update_component(component, %{body: "new_body"})
    end
  end

  describe "live data" do
    test "create broadcasts updated content event" do
      :ok = Beacon.PubSub.subscribe_to_content(:booted)
      %{site: site} = live_data_fixture(site: "booted")
      assert_receive {:content_updated, :live_data, %{site: ^site}}
    end

    test "create_live_data/1" do
      attrs = %{site: :my_site, path: "/foo/:bar"}

      assert {:ok, %LiveData{} = live_data} = Content.create_live_data(attrs)
      assert %{site: :my_site, path: "/foo/:bar"} = live_data
    end

    test "create_live_data/1 for root path" do
      attrs = %{site: :my_site, path: "/"}

      assert {:ok, %LiveData{} = live_data} = Content.create_live_data(attrs)
      assert %{site: :my_site, path: "/"} = live_data
    end

    test "create_assign_for_live_data/2" do
      live_data = live_data_fixture()
      attrs = %{key: "product_id", format: :elixir, value: "123"}

      assert {:ok, %LiveData{assigns: [assign]}} = Content.create_assign_for_live_data(live_data, attrs)
      assert %{key: "product_id", format: :elixir, value: "123"} = assign
    end

    test "validate assign elixir code on create" do
      live_data = live_data_fixture()

      attrs = %{key: "foo", value: "[1)", format: :elixir}
      assert {:error, %{errors: [error]}} = Content.create_assign_for_live_data(live_data, attrs)
      {:value, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected token: )"

      attrs = %{key: "foo", value: "if true, do false", format: :elixir}
      assert {:error, %{errors: [error]}} = Content.create_assign_for_live_data(live_data, attrs)
      {:value, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected reserved word: do"

      code = ~S|
      id = String.to_integer(params["id"])
      if id < 100, do: "less" <> "than", else: "100"
      |

      attrs = %{key: "foo", value: code, format: :elixir}
      assert {:ok, _} = Content.create_assign_for_live_data(live_data, attrs)
    end

    test "get_live_data/2" do
      live_data = live_data_fixture() |> Repo.preload(:assigns)

      assert Content.get_live_data(live_data.site, live_data.path) == live_data
    end

    test "live_data_for_site/1" do
      live_data_1 = live_data_fixture(site: :my_site, path: "/foo")
      live_data_2 = live_data_fixture(site: :my_site, path: "/bar")
      live_data_3 = live_data_fixture(site: :not_booted, path: "/baz")

      results = Content.live_data_for_site(:my_site)

      assert Enum.any?(results, &(&1.id == live_data_1.id))
      assert Enum.any?(results, &(&1.id == live_data_2.id))
      refute Enum.any?(results, &(&1.id == live_data_3.id))
    end

    test "live_data_for_site/2" do
      %{id: live_data_id} = live_data_fixture(site: :my_site)

      assert [%LiveData{id: ^live_data_id}] = Content.live_data_for_site(:my_site)
    end

    test "live_data_for_site/2 :query option" do
      %{id: foo_id} = live_data_fixture(site: :my_site, path: "/foo")
      %{id: bar_id} = live_data_fixture(site: :my_site, path: "/bar")

      assert [%LiveData{id: ^foo_id}] = Content.live_data_for_site(:my_site, query: "fo")
      assert [%LiveData{id: ^bar_id}] = Content.live_data_for_site(:my_site, query: "ba")
    end

    test "live_data_for_site/2 :per_page option" do
      %{id: foo_id} = live_data_fixture(site: :my_site, path: "/foo")
      %{id: bar_id} = live_data_fixture(site: :my_site, path: "/bar")
      %{id: baz_id} = live_data_fixture(site: :my_site, path: "/baz")
      %{id: bong_id} = live_data_fixture(site: :my_site, path: "/bong")

      assert [%{id: ^bar_id}] = Content.live_data_for_site(:my_site, per_page: 1)
      assert [%{id: ^bar_id}, %{id: ^baz_id}] = Content.live_data_for_site(:my_site, per_page: 2)
      assert [%{id: ^bar_id}, %{id: ^baz_id}, %{id: ^bong_id}] = Content.live_data_for_site(:my_site, per_page: 3)
      assert [%{id: ^bar_id}, %{id: ^baz_id}, %{id: ^bong_id}, %{id: ^foo_id}] = Content.live_data_for_site(:my_site, per_page: 4)
    end

    test "update_live_data_path/2" do
      live_data = live_data_fixture(site: :my_site, path: "/foo")

      assert {:ok, result} = Content.update_live_data_path(live_data, "/foo/:bar_id")
      assert result.id == live_data.id
      assert result.path == "/foo/:bar_id"
    end

    test "update_live_data_assign/2" do
      live_data = live_data_fixture()
      live_data_assign = live_data_assign_fixture(live_data: live_data)

      attrs = %{key: "wins", value: "1337", format: :elixir}
      assert {:ok, updated_assign} = Content.update_live_data_assign(live_data_assign, attrs)

      assert updated_assign.id == live_data_assign.id
      assert updated_assign.key == "wins"
      assert updated_assign.value == "1337"
      assert updated_assign.format == :elixir
    end

    test "validate assign elixir code on update" do
      live_data = live_data_fixture()
      live_data_assign = live_data_assign_fixture(live_data: live_data)

      attrs = %{value: "[1)", format: :elixir}
      assert {:error, %{errors: [error]}} = Content.update_live_data_assign(live_data_assign, attrs)
      {:value, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected token: )"

      attrs = %{value: "if true, do false", format: :elixir}
      assert {:error, %{errors: [error]}} = Content.update_live_data_assign(live_data_assign, attrs)
      {:value, {_, [compilation_error: compilation_error]}} = error
      assert compilation_error =~ "unexpected reserved word: do"

      code = ~S|
      id = String.to_integer(params["id"])
      if id < 100, do: "less" <> "than", else: "100"
      |

      attrs = %{value: code, format: :elixir}
      assert {:ok, _} = Content.update_live_data_assign(live_data_assign, attrs)
    end

    test "delete_live_data/1" do
      live_data = live_data_fixture()

      assert [%{}] = Content.live_data_for_site(live_data.site)
      assert {:ok, _} = Content.delete_live_data(live_data)
      assert [] = Content.live_data_for_site(live_data.site)
    end

    test "delete_live_data_assign/1" do
      live_data = live_data_fixture()
      live_data_assign = live_data_assign_fixture(live_data: live_data)
      Repo.preload(live_data, :assigns)

      assert {:ok, _} = Content.delete_live_data_assign(live_data_assign)
      assert %{assigns: []} = Repo.preload(live_data, :assigns)
    end
  end
end
