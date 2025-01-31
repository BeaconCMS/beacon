defmodule Beacon.LoaderTest do
  use Beacon.DataCase, async: false
  use Beacon.Test, site: :my_site
  alias Beacon.Content
  alias Beacon.Loader
  alias Beacon.BeaconTest.Repo
  alias Phoenix.LiveView.Rendered

  setup do
    site = default_site()

    # we aren't spawning Workers in these tests so we have to locally
    # enable the ErrorHandler and set the site in the Process dictionary
    # (which would normally happen in the Worker `init/1`)
    Process.put(:__beacon_site__, site)
    Process.flag(:error_handler, Beacon.ErrorHandler)

    [site: site]
  end

  describe "safe_apply_mfa" do
    setup do
      # reset (turn off) beacon autoloader
      Process.delete(:__beacon_site__)
      Process.flag(:error_handler, :error_handler)
      :ok
    end

    test "loaded module" do
      assert Loader.safe_apply_mfa(default_site(), String, :to_integer, ["1"]) == 1
    end

    test "undefined module" do
      assert_raise Beacon.InvokeError, "error applying Foo.bar/0 on site my_site", fn ->
        Loader.safe_apply_mfa(default_site(), Foo, :bar, [])
      end
    end

    test "undefined function" do
      assert_raise Beacon.InvokeError, "error applying String.foo/1 on site my_site", fn ->
        Loader.safe_apply_mfa(default_site(), String, :foo, ["bar"])
      end
    end

    test "forwards live data errors" do
      live_data = beacon_live_data_fixture(path: "/error")
      beacon_live_data_assign_fixture(live_data: live_data, format: :elixir, key: "test", value: "String.foo()")

      assert_raise UndefinedFunctionError, "function String.foo/0 is undefined or private", fn ->
        assert assigns_for_path("/error")
      end
    end

    defp assigns_for_path(path) do
      path_list = String.split(path, "/", trim: true)
      module = Beacon.Loader.fetch_live_data_module(default_site())
      module.live_data(path_list, %{})
    end
  end

  describe "populate default components" do
    test "seeds initial data", %{site: site} do
      assert Repo.all(Content.Component) == []
      assert Loader.populate_default_components(site) == :ok
      assert Repo.all(Content.Component) |> length() > 0
    end
  end

  describe "populate default layouts" do
    test "seeds initial data", %{site: site} do
      assert Repo.all(Content.Layout) == []
      assert Loader.populate_default_layouts(site) == :ok
      assert Repo.all(Content.Layout) |> length() > 0
    end
  end

  describe "populate default error pages" do
    setup %{site: site} do
      Loader.populate_default_layouts(site)
    end

    test "seeds initial data", %{site: site} do
      assert Repo.all(Content.ErrorPage) == []
      assert Loader.populate_default_error_pages(site) == :ok
      assert Repo.all(Content.ErrorPage) |> length() > 0
    end
  end

  describe "snippets" do
    test "loads module even without snippets helpers available", %{site: site} do
      module = Loader.load_snippets_module(site)
      assert :erlang.module_loaded(module)
    end

    test "loads module containing all snippet helpers", %{site: site} do
      beacon_snippet_helper_fixture()
      module = Loader.fetch_snippets_module(site)
      assert module.upcase_title(%{"page" => %{"title" => "Beacon"}}) == "BEACON"
    end
  end

  describe "components" do
    setup do
      beacon_component_fixture(name: "a", template: "<h1>A</h1>")
      :ok
    end

    test "loads module containing all components", %{site: site} do
      module = Loader.fetch_components_module(site)
      assert %Rendered{static: ["<h1>A</h1>"]} = module.my_component("a", %{})
      assert %Rendered{static: ["<h1>A</h1>"]} = module.render("a", %{})
    end

    test "adding or removing components reloads the component module", %{site: site} do
      beacon_component_fixture(name: "b", template: "<h1>B</h1>")

      module = Loader.fetch_components_module(site)
      assert %Rendered{static: ["<h1>A</h1>"]} = module.my_component("a", %{})
      assert %Rendered{static: ["<h1>B</h1>"]} = module.my_component("b", %{})

      Repo.delete_all(Content.Component)
      Loader.load_components_module(site)

      assert_raise Beacon.InvokeError, fn ->
        module.my_component("a", %{})
      end
    end
  end

  describe "live data" do
    setup do
      beacon_live_data_assign_fixture()
      :ok
    end

    test "loads module containing all live data", %{site: site} do
      module = Loader.fetch_live_data_module(site)
      assert module.live_data(["foo", "bar"], %{}) == %{bar: "Hello world!"}
    end
  end

  describe "error pages" do
    setup do
      beacon_error_page_fixture()
      :ok
    end

    test "loads module containing all page errors", %{site: site} do
      conn = Phoenix.ConnTest.build_conn()
      module = Loader.load_error_page_module(site)
      assert module.render(conn, 404) == "Not Found"
    end
  end

  describe "stylesheets" do
    setup do
      beacon_stylesheet_fixture()
      :ok
    end

    test "loads module containing all stylesheets", %{site: site} do
      module = Loader.load_stylesheet_module(site)
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

    test "loads page module", %{site: site, page_a: page} do
      module = Loader.load_page_module(site, page.id)
      assert %{path: "/a"} = module.page_assigns()
      assert %Rendered{static: ["<h1>A</h1>"]} = module.render(%{})
    end

    test "unload page", %{page_a: page} do
      module = Loader.load_page_module(page.site, page.id)
      assert :erlang.module_loaded(module)
      Loader.unload_page_module(page.site, page.id)
      refute :erlang.module_loaded(module)
    end
  end
end
