defmodule Beacon.Loader.DBLoader do
  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Loader.ComponentModuleLoader
  alias Beacon.Loader.LayoutModuleLoader
  alias Beacon.Loader.PageModuleLoader
  alias Beacon.Pages

  def load_from_db do
    load_components()
    load_layouts()
    load_pages()
  end

  def load_components do
    Components.list_components()
    |> Enum.group_by(& &1.site, & &1)
    |> Enum.each(fn {site, components} ->
      {:ok, _} = ComponentModuleLoader.load_components(site, components)
    end)

    :ok
  end

  def load_layouts do
    Layouts.list_layouts()
    |> Enum.group_by(& &1.site, & &1)
    |> Enum.each(fn {site, layouts} ->
      {:ok, _} = LayoutModuleLoader.load_layouts(site, layouts)
    end)

    :ok
  end

  def load_pages do
    Pages.list_pages()
    |> Enum.group_by(& &1.site, & &1)
    |> Enum.each(fn {site, pages} ->
      {:ok, _} = PageModuleLoader.load_templates(site, pages)

      Enum.map(pages, &Beacon.PubSub.broadcast_page_update(site, &1.path))
    end)

    :ok
  end
end
