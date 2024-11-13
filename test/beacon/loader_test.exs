defmodule Beacon.LoaderTest do
  use Beacon.DataCase, async: false
  use Beacon.Test, site: :my_site
  alias Beacon.Content
  alias Beacon.Loader
  alias Beacon.BeaconTest.Repo
  alias Phoenix.LiveView.Rendered

  describe "populate default components" do
    test "seeds initial data" do
      assert Repo.all(Content.Component) == []
      assert Loader.populate_default_components(default_site()) == :ok
      assert Repo.all(Content.Component) |> length() > 0
    end
  end

  describe "populate default layouts" do
    test "seeds initial data" do
      assert Repo.all(Content.Layout) == []
      assert Loader.populate_default_layouts(default_site()) == :ok
      assert Repo.all(Content.Layout) |> length() > 0
    end
  end

  describe "populate default error pages" do
    setup do
      Loader.populate_default_layouts(default_site())
    end

    test "seeds initial data" do
      assert Repo.all(Content.ErrorPage) == []
      assert Loader.populate_default_error_pages(default_site()) == :ok
      assert Repo.all(Content.ErrorPage) |> length() > 0
    end
  end

  describe "snippets" do
    test "loads module even without snippets helpers available" do
      {:ok, module} = Loader.load_snippets_module(default_site())
      assert :erlang.module_loaded(module)
    end

    test "loads module containing all snippet helpers" do
      beacon_snippet_helper_fixture()
      module = Loader.fetch_snippets_module(default_site())
      assert module.upcase_title(%{"page" => %{"title" => "Beacon"}}) == "BEACON"
    end
  end

  describe "components" do
    setup do
      beacon_component_fixture(name: "a", template: "<h1>A</h1>")
      :ok
    end

    test "loads module containing all components" do
      module = Loader.fetch_components_module(default_site())
      assert %Rendered{static: ["<h1>A</h1>"]} = module.my_component("a", %{})
      assert %Rendered{static: ["<h1>A</h1>"]} = module.render("a", %{})
    end

    test "adding or removing components reloads the component module" do
      beacon_component_fixture(name: "b", template: "<h1>B</h1>")

      module = Loader.fetch_components_module(default_site())
      assert %Rendered{static: ["<h1>A</h1>"]} = module.my_component("a", %{})
      assert %Rendered{static: ["<h1>B</h1>"]} = module.my_component("b", %{})

      Repo.delete_all(Content.Component)
      Loader.load_components_module(default_site())

      assert_raise Beacon.RuntimeError, fn ->
        module.my_component("a", %{})
      end
    end
  end

  describe "live data" do
    setup do
      beacon_live_data_assign_fixture()
      :ok
    end

    test "loads module containing all live data" do
      module = Loader.fetch_live_data_module(default_site())
      assert module.live_data(["foo", "bar"], %{}) == %{bar: "Hello world!"}
    end
  end

  describe "error pages" do
    setup do
      beacon_error_page_fixture()
      :ok
    end

    test "loads module containing all page errors" do
      conn = Phoenix.ConnTest.build_conn()
      {:ok, module} = Loader.load_error_page_module(default_site())
      assert module.render(conn, 404) == "Not Found"
    end
  end

  describe "stylesheets" do
    setup do
      beacon_stylesheet_fixture()
      :ok
    end

    test "loads module containing all stylesheets" do
      {:ok, module} = Loader.load_stylesheet_module(default_site())
      assert module.render() =~ "sample_stylesheet"
    end
  end

  describe "layouts" do
    setup do
      layout_a = beacon_published_layout_fixture(template: "<h1>A</h1>")
      layout_b = beacon_published_layout_fixture(template: "<h1>B</h1>")
      [layout_a: layout_a, layout_b: layout_b]
    end
  end

  describe "pages" do
    setup do
      layout = beacon_published_layout_fixture()
      page_a = beacon_published_page_fixture(layout_id: layout.id, path: "/a", template: "<h1>A</h1>")
      page_b = beacon_published_page_fixture(layout_id: layout.id, path: "/b", template: "<h1>B</h1>")
      [page_a: page_a, page_b: page_b]
    end

    test "loads page module", %{page_a: page} do
      {:ok, module} = Loader.load_page_module(default_site(), page.id)
      assert %{path: "/a"} = module.page_assigns()
      assert %Rendered{static: ["<h1>A</h1>"]} = module.render(%{})
    end

    test "unload page", %{page_a: page} do
      {:ok, module} = Loader.load_page_module(page.site, page.id)
      assert :erlang.module_loaded(module)
      Loader.unload_page_module(page.site, page.id)
      refute :erlang.module_loaded(module)
    end
  end
end
