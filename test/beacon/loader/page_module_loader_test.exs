defmodule Beacon.Loader.PageModuleLoaderTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures
  alias Beacon.Loader.PageModuleLoader
  alias Beacon.Repo

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  describe "dynamic_helper" do
    test "generate each helper function and the proxy dynamic_helper" do
      page_1 = page_fixture(site: "my_site", path: "1", helpers: [page_helper_params(name: "page_1_upcase")])
      page_2 = page_fixture(site: "my_site", path: "2", helpers: [page_helper_params(name: "page_2_upcase")])
      [page_1, page_2] = Repo.preload([page_1, page_2], :event_handlers)

      {:ok, _module, ast} = PageModuleLoader.load_page!(page_1)
      assert has_function?(ast, :page_1_upcase)
      assert has_function?(ast, :dynamic_helper)

      {:ok, _module, ast} = PageModuleLoader.load_page!(page_2)
      assert has_function?(ast, :page_2_upcase)
      assert has_function?(ast, :dynamic_helper)
    end
  end

  defp has_function?(ast, helper_name) do
    {_new_ast, present} =
      Macro.prewalk(ast, false, fn
        {^helper_name, _, _} = node, _acc -> {node, true}
        node, true -> {node, true}
        node, false -> {node, false}
      end)

    present
  end

  describe "page_assigns/1" do
    test "interpolates raw_schema snippets" do
      snippet_helper_fixture(%{
        site: "my_site",
        name: "raw_schema_author_name",
        body: ~S"""
        author_id =  get_in(assigns, ["page", "extra", "author_id"])
        "author_#{author_id}"
        """
      })

      layout = published_layout_fixture()

      page =
        [
          site: "my_site",
          layout_id: layout.id,
          path: "page/raw-schema",
          title: "my first page",
          description: "hello world",
          extra: %{
            "author_id" => 1
          },
          raw_schema: [
            %{
              "@context": "https://schema.org",
              "@type": "BlogPosting",
              headline: "{{ page.description }}",
              author: %{
                "@type": "Person",
                name: "{% helper 'raw_schema_author_name' %}"
              }
            }
          ]
        ]
        |> page_fixture()
        |> Repo.preload(:event_handlers)

      {:ok, module, _ast} = PageModuleLoader.load_page!(page)

      [raw_schema] = module.page_assigns().raw_schema

      assert Enum.sort(raw_schema) == [
               "@context": "https://schema.org",
               "@type": "BlogPosting",
               author: %{name: "author_1", "@type": "Person"},
               headline: "hello world"
             ]
    end
  end

  describe "render" do
    test "do not load template on boot stage" do
      page = page_fixture(site: "my_site", path: "1") |> Repo.preload([:event_handlers, :variants])
      {:ok, module, _ast} = PageModuleLoader.load_page!(page, :boot)
      assert module.render(%{}) == :not_loaded
    end

    test "render primary template" do
      page = page_fixture(site: "my_site", path: "1") |> Repo.preload([:event_handlers, :variants])
      {:ok, module, _ast} = PageModuleLoader.load_page!(page)
      assert %Phoenix.LiveView.Rendered{static: ["<main>\n  <h1>my_site#home</h1>\n</main>"]} = module.render(%{})
    end

    test "render all templates" do
      page = page_fixture(site: "my_site", path: "1")
      Beacon.Content.create_variant_for_page(page, %{name: "variant_a", weight: 1, template: "<div>variant_a</div>"})
      Beacon.Content.create_variant_for_page(page, %{name: "variant_b", weight: 2, template: "<div>variant_b</div>"})
      page = Repo.preload(page, [:event_handlers, :variants])
      {:ok, module, _ast} = PageModuleLoader.load_page!(page)

      assert [
               %Phoenix.LiveView.Rendered{static: ["<main>\n  <h1>my_site#home</h1>\n</main>"]},
               {1, %Phoenix.LiveView.Rendered{static: ["<div>variant_a</div>"]}},
               {2, %Phoenix.LiveView.Rendered{static: ["<div>variant_b</div>"]}}
             ] = module.templates(%{})
    end
  end

  describe "loading" do
    test "unload page" do
      page = page_fixture(site: "my_site", path: "1") |> Repo.preload([:event_handlers, :variants])
      {:ok, module, _ast} = PageModuleLoader.load_page!(page)
      assert :erlang.module_loaded(module)

      PageModuleLoader.unload_page!(page)
      refute :erlang.module_loaded(module)
    end
  end
end
