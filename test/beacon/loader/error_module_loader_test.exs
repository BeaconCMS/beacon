defmodule Beacon.Loader.ErrorModuleLoaderTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures

  alias Beacon.Loader.ErrorModuleLoader

  @site :my_site

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  test "render default error pages" do
    :ok = Beacon.Loader.populate_layouts(@site)
    :ok = Beacon.Loader.populate_error_pages(@site)
    error_module = load_error_pages_module(@site)

    assert error_module.render(404) == "Not Found"
    assert error_module.render(500) == "Internal Server Error"
  end

  test "render custom error page with layout" do
    layout = published_layout_fixture(template: "Wow\n<%= @inner_content %>\nLayout", site: @site)
    error_page = error_page_fixture(layout: layout, template: "Error", site: @site)
    error_module = load_error_pages_module(@site)

    assert error_module.render(error_page.status) == "Wow\nError\nLayout"
  end

  defp load_error_pages_module(site) do
    {:ok, module, _ast} =
      site
      |> Beacon.Content.list_error_pages()
      |> Beacon.Repo.preload(:layout)
      |> ErrorModuleLoader.load_error_pages!(site)

    module
  end
end
