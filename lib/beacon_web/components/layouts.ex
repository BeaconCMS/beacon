defmodule BeaconWeb.Layouts do
  @moduledoc false

  use BeaconWeb, :html
  require Logger

  embed_templates "layouts/*"

  beacon_admin_css_path = Path.join(__DIR__, "../../../priv/static/assets/admin.css")
  @external_resource beacon_admin_css_path

  # TODO: style nonce
  def static_asset_path(conn, asset) when asset in [:css, :js] do
    %{assigns: %{__site__: site}} = conn
    prefix = conn.private.phoenix_router.__beacon_site_prefix__()

    hash =
      cond do
        asset == :css -> Beacon.RuntimeCSS.current_hash(site)
        asset == :js -> Beacon.RuntimeJS.current_hash()
      end

    Beacon.Router.sanitize_path("#{prefix}/beacon_static/#{asset}-#{hash}")
  end

  def admin_static_asset_path(conn, asset) when asset in [:css, :js] do
    if asset == :css && Code.ensure_loaded?(Mix.Project) && Mix.env() in [:test, :dev] do
      "/dev/assets/admin.css"
    else
      prefix = conn.private.phoenix_router.__beacon_admin_prefix__()

      hash =
        cond do
          asset == :css -> Beacon.RuntimeCSS.current_hash(:beacon_admin)
          asset == :js -> Beacon.RuntimeJS.current_hash()
        end

      Beacon.Router.sanitize_path("#{prefix}/beacon_static/#{asset}-#{hash}")
    end
  end

  def render_dynamic_layout(%{__dynamic_layout_id__: layout_id, __site__: site} = assigns) do
    site
    |> Beacon.Loader.layout_module_for_site()
    |> Beacon.Loader.call_function_with_retry(:render, [layout_id, assigns])
  end

  def live_socket_path(%{__site__: site}) do
    Beacon.Config.fetch!(site).live_socket_path
  end

  defp compiled_page_assigns(site, page_id) do
    site
    |> Beacon.Loader.page_module_for_site()
    |> Beacon.Loader.call_function_with_retry(:page_assigns, [page_id])
  end

  defp compiled_layout_assigns(site, layout_id) do
    site
    |> Beacon.Loader.layout_module_for_site()
    |> Beacon.Loader.call_function_with_retry(:layout_assigns, [layout_id])
  end

  def render_page_title(%{__dynamic_page_id__: _, __site__: site, __live_path__: path} = assigns) do
    params = Map.drop(assigns.conn.params, ["path"])
    Beacon.DataSource.page_title(site, path, params, assigns.beacon_live_data, page_title(assigns))
  end

  def render_page_title(assigns), do: page_title(assigns)

  @doc false
  def page_title(%{__dynamic_layout_id__: layout_id, __dynamic_page_id__: page_id, __site__: site}) do
    %{title: page_title} =
      site
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry(:page_assigns, [page_id])

    if page_title do
      page_title
    else
      %{title: layout_title} =
        site
        |> Beacon.Loader.layout_module_for_site()
        |> Beacon.Loader.call_function_with_retry(:layout_assigns, [layout_id])

      layout_title || missing_page_title()
    end
  end

  def page_title(_), do: missing_page_title()

  defp missing_page_title do
    Logger.warning("No page title set")
    ""
  end

  @doc """
  Render all page, layout, and site meta tags.

  See `Beacon.default_site_meta_tags/0` for a list of default meta tags
  that are included in all pages.
  """

  def render_meta_tags(%{__dynamic_page_id__: _, __site__: site, __live_path__: path} = assigns) do
    params = Map.drop(assigns.conn.params, ["path"])

    do_render_meta_tags(
      assigns,
      Beacon.DataSource.meta_tags(site, path, params, assigns.beacon_live_data, meta_tags(assigns))
    )
  end

  def render_meta_tags(assigns) do
    do_render_meta_tags(assigns, meta_tags(assigns))
  end

  defp do_render_meta_tags(assigns, meta_tags) do
    assigns = assign(assigns, :meta_tags, meta_tags)

    ~H"""
    <%= for meta_attributes <- @meta_tags do %>
      <meta {meta_attributes} />
    <% end %>
    """
  end

  @doc """
  List of all meta tags, including site, layout, and page.
  """
  def meta_tags(assigns) do
    page_meta_tags = page_meta_tags(assigns) || []
    layout_meta_tags = layout_meta_tags(assigns) || []

    (page_meta_tags ++ layout_meta_tags)
    |> Enum.reject(&(&1["name"] == "csrf-token"))
    |> Kernel.++(Beacon.default_site_meta_tags())
  end

  defp page_meta_tags(%{page_assigns: %{meta_tags: meta_tags}} = assigns) do
    assigns
    |> compiled_page_meta_tags()
    |> Map.merge(meta_tags)
  end

  defp page_meta_tags(assigns) do
    compiled_page_meta_tags(assigns)
  end

  defp compiled_page_meta_tags(%{__dynamic_page_id__: page_id, __site__: site}) do
    %{meta_tags: meta_tags} = compiled_page_assigns(site, page_id)
    meta_tags
  end

  defp layout_meta_tags(%{layout_assigns: %{meta_tags: meta_tags}} = assigns) do
    assigns
    |> compiled_layout_meta_tags()
    |> Map.merge(meta_tags)
  end

  defp layout_meta_tags(assigns) do
    compiled_layout_meta_tags(assigns)
  end

  defp compiled_layout_meta_tags(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{meta_tags: meta_tags} = compiled_layout_assigns(site, layout_id)
    meta_tags
  end

  def dynamic_layout?(%{__dynamic_layout_id__: _}), do: true
  def dynamic_layout?(_), do: false

  def stylesheet_tag(%{__dynamic_layout_id__: _, __site__: site}) do
    stylesheet_tag =
      site
      |> Beacon.Loader.stylesheet_module_for_site()
      |> Beacon.Loader.call_function_with_retry(:render, [])

    {:safe, stylesheet_tag}
  end

  def stylesheet_tag(_), do: ""

  def linked_stylesheets(%{__dynamic_layout_id__: _, __site__: _} = assigns) do
    {:safe, linked_stylesheets_unsafe(assigns)}
  end

  def linked_stylesheets(_), do: ""

  def linked_stylesheets_unsafe(assigns) do
    assigns
    |> get_linked_stylesheets()
    |> Enum.map_join("\n", fn sheet ->
      # TODO: escape key/values here
      ~s(    <link rel="stylesheet" href="#{sheet}">)
    end)
  end

  # for non dynamic pages

  def get_linked_stylesheets(%{layout_assigns: %{linked_stylesheets: linked_stylesheets}} = assigns) do
    assigns
    |> compiled_linked_stylesheets()
    |> Map.merge(linked_stylesheets)
  end

  def get_linked_stylesheets(assigns) do
    compiled_linked_stylesheets(assigns)
  end

  defp compiled_linked_stylesheets(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{stylesheet_urls: compiled_linked_stylesheets} = compiled_layout_assigns(site, layout_id)
    compiled_linked_stylesheets
  end
end
