defmodule BeaconWeb.Layouts do
  @moduledoc false

  use BeaconWeb, :html
  require Logger

  embed_templates "layouts/*"

  # TODO: style nonce
  def asset_path(conn, asset) when asset in [:css, :js] do
    %{assigns: %{__site__: site}} = conn
    prefix = router(conn).__beacon_scoped_prefix_for_site__(site)

    hash =
      cond do
        asset == :css -> Beacon.RuntimeCSS.current_hash(site)
        asset == :js -> Beacon.RuntimeJS.current_hash()
      end

    path = Beacon.Router.sanitize_path("#{prefix}/beacon_assets/#{asset}-#{hash}")
    Phoenix.VerifiedRoutes.unverified_path(conn, conn.private.phoenix_router, path)
  end

  defp router(%Plug.Conn{private: %{phoenix_router: router}}), do: router
  defp router(%Phoenix.LiveView.Socket{router: router}), do: router

  def dynamic_layout?(%{__dynamic_layout_id__: _}), do: true
  def dynamic_layout?(_), do: false

  def render_dynamic_layout(%{__dynamic_layout_id__: layout_id, __site__: site} = assigns) do
    site
    |> Beacon.Loader.layout_module_for_site(layout_id)
    |> Beacon.Loader.call_function_with_retry(:render, [layout_id, assigns])
  end

  def live_socket_path(%{__site__: site}) do
    Beacon.Config.fetch!(site).live_socket_path
  end

  defp compiled_page_assigns(site, page_id) do
    site
    |> Beacon.Loader.page_module_for_site(page_id)
    |> Beacon.Loader.call_function_with_retry(:page_assigns, [page_id])
  end

  defp compiled_layout_assigns(site, layout_id) do
    site
    |> Beacon.Loader.layout_module_for_site(layout_id)
    |> Beacon.Loader.call_function_with_retry(:layout_assigns, [layout_id])
  end

  def render_page_title(%{__dynamic_page_id__: _, __site__: site, __live_path__: path} = assigns) do
    params = Map.drop(assigns.conn.params, ["path"])
    Beacon.DataSource.page_title(site, path, params, assigns.beacon_live_data, page_title(assigns))
  end

  def render_page_title(assigns), do: page_title(assigns)

  def page_title(%{__dynamic_layout_id__: layout_id, __dynamic_page_id__: page_id, __site__: site}) do
    %{title: page_title} =
      site
      |> Beacon.Loader.page_module_for_site(page_id)
      |> Beacon.Loader.call_function_with_retry(:page_assigns, [page_id])

    if page_title do
      page_title
    else
      %{title: layout_title} =
        site
        |> Beacon.Loader.layout_module_for_site(layout_id)
        |> Beacon.Loader.call_function_with_retry(:layout_assigns, [layout_id])

      layout_title || missing_page_title()
    end
  end

  def page_title(_), do: missing_page_title()

  defp missing_page_title do
    Logger.warning("No page title set")
    ""
  end

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

  def meta_tags(assigns) do
    page_meta_tags = page_meta_tags(assigns) || []
    layout_meta_tags = layout_meta_tags(assigns) || []

    (page_meta_tags ++ layout_meta_tags)
    |> Enum.reject(&(&1["name"] == "csrf-token"))
    |> Kernel.++(Beacon.Content.default_site_meta_tags())
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

  def render_schema(%{__dynamic_page_id__: page_id, __site__: site} = assigns) do
    %{raw_schema: raw_schema} =
      site
      |> Beacon.Loader.page_module_for_site(page_id)
      |> Beacon.Loader.call_function_with_retry(:page_assigns, [page_id])

    is_empty = fn raw_schema ->
      raw_schema |> Enum.map(&Map.values/1) |> List.flatten() == []
    end

    if is_empty.(raw_schema) do
      []
    else
      assigns = assign(assigns, :raw_schema, Jason.encode!(raw_schema))

      ~H"""
      <script type="application/ld+json">
        <%= {:safe, @raw_schema} %>
      </script>
      """
    end
  end

  def render_resource_links(%{__dynamic_layout_id__: _, __site__: _} = assigns) do
    resource_links = layout_resource_links(assigns) || []
    assigns = assign(assigns, :resource_links, resource_links)

    ~H"""
    <%= for attr <- @resource_links do %>
      <link {attr} />
    <% end %>
    """
  end

  def render_resource_links(_assigns), do: []

  defp layout_resource_links(%{layout_assigns: %{resource_links: resource_links}} = assigns) do
    assigns
    |> compiled_layout_resource_links()
    |> Map.merge(resource_links)
  end

  defp layout_resource_links(assigns) do
    compiled_layout_resource_links(assigns)
  end

  defp compiled_layout_resource_links(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{resource_links: resource_links} = compiled_layout_assigns(site, layout_id)
    resource_links
  end
end
