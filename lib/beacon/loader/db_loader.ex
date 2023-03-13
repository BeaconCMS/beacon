defmodule Beacon.Loader.DBLoader do
  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Loader.ComponentModuleLoader
  alias Beacon.Loader.LayoutModuleLoader
  alias Beacon.Loader.PageModuleLoader
  alias Beacon.Loader.StylesheetModuleLoader
  alias Beacon.Pages
  alias Beacon.Stylesheets
  require Logger

  # TODO: double check if caller can pass `site` to avoid reloading all sites
  def load_from_db do
    for site <- Beacon.Registry.registered_sites() do
      load_from_db(site)
    end

    :ok
  end

  def load_from_db(site) do
    :ok = Beacon.RuntimeJS.load()
    :ok = Beacon.RuntimeCSS.load_admin()
    load_runtime_css(site)
    load_components(site)
    load_layouts(site)
    load_pages(site)
    load_stylesheets(site)

    :ok
  end

  def load_components(site) do
    ComponentModuleLoader.load_components(site, Components.list_components_for_site(site))
  end

  def load_layouts(site) do
    LayoutModuleLoader.load_layouts(site, Layouts.list_layouts_for_site(site))
  end

  def load_pages(site) do
    pages = Pages.list_pages_for_site(site, [:events, :helpers])
    module = PageModuleLoader.load_templates(site, pages)
    Enum.each(pages, &Beacon.PubSub.broadcast_page_update(site, &1.path))

    module
  end

  def load_stylesheets(site) do
    StylesheetModuleLoader.load_stylesheets(site, Stylesheets.list_stylesheets_for_site(site))
  end

  def load_runtime_css(site) do
    # TODO: control loading by env when we get to refactor/improve Server
    if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
      ""
    else
      Beacon.RuntimeCSS.load(site)
    end
  end
end
