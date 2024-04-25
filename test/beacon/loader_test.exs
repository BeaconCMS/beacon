defmodule Beacon.LoaderTest do
  use Beacon.DataCase, async: false
  import Beacon.Fixtures
  alias Beacon.Content
  alias Beacon.Loader
  alias Beacon.Repo
  alias Phoenix.LiveView.Rendered

  @site :my_site

  describe "populate default components" do
    test "seeds initial data" do
      assert Repo.all(Content.Component) == []
      assert Loader.populate_default_components(@site) == :ok
      assert Repo.all(Content.Component) |> length() > 0
    end
  end

  describe "populate default layouts" do
    test "seeds initial data" do
      assert Repo.all(Content.Layout) == []
      assert Loader.populate_default_layouts(@site) == :ok
      assert Repo.all(Content.Layout) |> length() > 0
    end
  end

  describe "populate default error pages" do
    setup do
      Loader.populate_default_layouts(@site)
    end

    test "seeds initial data" do
      assert Repo.all(Content.ErrorPage) == []
      assert Loader.populate_default_error_pages(@site) == :ok
      assert Repo.all(Content.ErrorPage) |> length() > 0
    end
  end

  describe "snippets" do
    test "loads module even without snippets helpers available" do
      module = Loader.reload_snippets_module(@site)
      assert :erlang.module_loaded(module)
    end

    test "loads module containing all snippet helpers" do
      snippet_helper_fixture()
      module = Loader.reload_snippets_module(@site)
      assert module.upcase_title(%{"page" => %{"title" => "Beacon"}}) == "BEACON"
    end
  end

  describe "components" do
    setup do
      component_fixture(name: "a", body: "<h1>A</h1>")
      :ok
    end

    test "loads module containing all components" do
      module = Loader.reload_components_module(@site)
      assert %Rendered{static: ["<h1>A</h1>"]} = module.my_component("a", %{})
      assert %Rendered{static: ["<h1>A</h1>"]} = module.render("a", %{})
    end

    test "adding or removing components reloads the component module" do
      module = Loader.reload_components_module(@site)

      component_fixture(name: "b", body: "<h1>B</h1>")
      assert %Rendered{static: ["<h1>A</h1>"]} = module.my_component("a", %{})
      assert %Rendered{static: ["<h1>B</h1>"]} = module.my_component("b", %{})

      Repo.delete_all(Content.Component)
      Loader.reload_components_module(@site)

      assert_raise Beacon.RuntimeError, fn ->
        module.my_component("a", %{})
      end
    end
  end

  describe "live data" do
    setup do
      live_data_assign_fixture()
      :ok
    end

    test "loads module containing all live data" do
      module = Loader.reload_live_data_module(@site)
      assert module.live_data(["foo", "bar"], %{}) == %{bar: "Hello world!"}
    end
  end

  describe "error pages" do
    setup do
      error_page_fixture()
      :ok
    end

    test "loads module containing all page errors" do
      conn = Phoenix.ConnTest.build_conn()
      module = Loader.reload_error_page_module(@site)
      assert module.render(conn, 404) == "Not Found"
    end
  end

  describe "stylesheets" do
    setup do
      stylesheet_fixture()
      :ok
    end

    test "loads module containing all stylesheets" do
      module = Loader.reload_stylesheet_module(@site)
      assert module.render() =~ "sample_stylesheet"
    end
  end

  describe "layouts" do
    setup do
      layout_a = published_layout_fixture(template: "<h1>A</h1>")
      layout_b = published_layout_fixture(template: "<h1>B</h1>")
      [layout_a: layout_a, layout_b: layout_b]
    end

    test "reloads all layouts into separate modules" do
      [module_a, module_b] = Loader.reload_layouts_modules(@site)
      assert %Rendered{} = module_a.render(%{})
      assert %Rendered{} = module_b.render(%{})
    end
  end

  describe "pages" do
    setup do
      layout = published_layout_fixture()
      page_a = published_page_fixture(layout_id: layout.id, path: "/a", template: "<h1>A</h1>")
      page_b = published_page_fixture(layout_id: layout.id, path: "/b", template: "<h1>B</h1>")
      [page_a: page_a, page_b: page_b]
    end

    test "reloads all pages into separate modules" do
      [module_a, module_b] = Loader.reload_pages_modules(@site)
      assert %Rendered{} = module_a.render(%{})
      assert %Rendered{} = module_b.render(%{})
    end

    test "loads page module", %{page_a: page} do
      module = Loader.reload_page_module(@site, page.id)
      assert %{path: "/a"} = module.page_assigns()
      assert %Rendered{static: ["<h1>A</h1>"]} = module.render(%{})
    end

    test "unload page", %{page_a: page} do
      module = Loader.fetch_page_module(page.site, page.id)
      assert :erlang.module_loaded(module)
      Loader.unload_page_module(page.site, page.id)
      refute :erlang.module_loaded(module)
    end
  end
end
