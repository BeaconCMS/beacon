defmodule Beacon.Loader.DBLoader do
  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Loader.ComponentModuleLoader
  alias Beacon.Loader.LayoutModuleLoader
  alias Beacon.Loader.PageModuleLoader
  alias Beacon.Loader.StylesheetModuleLoader
  alias Beacon.Pages
  alias Beacon.Stylesheets

  def load_from_db do
    load_components()
    load_layouts()
    load_pages()
    load_stylesheets()
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

  def load_stylesheets do
    Stylesheets.list_stylesheets()
    |> Enum.group_by(& &1.site, & &1)
    |> Enum.each(fn {site, stylesheets} ->
      {:ok, _} = StylesheetModuleLoader.load_stylesheets(site, stylesheets)
    end)

    :ok
  end
end
