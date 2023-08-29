defmodule Beacon.Loader.ErrorModuleLoaderTest do
  use Beacon.DataCase, async: false

  alias Beacon.Loader.ErrorModuleLoader

  @site :my_site

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  test "render default error pages" do
    :ok = Beacon.Loader.populate_layouts(@site)
    :ok = Beacon.Loader.populate_error_pages(@site)

    {:ok, module, _ast} =
      @site
      |> Beacon.Content.list_error_pages()
      |> Beacon.Repo.preload(:layout)
      |> ErrorModuleLoader.load_error_pages!(@site)

    assert module.render(404) == "Not Found"
    assert module.render(500) == "Internal Server Error"
  end
end
