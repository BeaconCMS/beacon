defmodule BeaconWeb.Layouts do
  @moduledoc false

  use BeaconWeb, :html
  require Logger

  embed_templates "layouts/*"

  # TODO: style nonce
  def asset_path(%{assigns: %{beacon: %{site: site}}} = conn, asset) when asset in [:css, :js] do
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

  def render_dynamic_layout(assigns) do
    %{beacon: %{site: site, private: %{layout_id: layout_id}}} = assigns

    site
    |> Beacon.Loader.fetch_layout_module(layout_id)
    |> Beacon.apply_mfa(:render, [assigns])
  end

  def live_socket_path(assigns) do
    %{beacon: %{site: site}} = assigns
    Beacon.Config.fetch!(site).live_socket_path
  end

  defp compiled_page_assigns(site, page_id) do
    site
    |> Beacon.Loader.fetch_page_module(page_id)
    |> Beacon.apply_mfa(:page_assigns, [])
  end

  defp compiled_layout_assigns(site, layout_id) do
    site
    |> Beacon.Loader.fetch_layout_module(layout_id)
    |> Beacon.apply_mfa(:layout_assigns, [])
  end

  def render_page_title(assigns) do
    %{beacon: %{site: site, private: %{page_id: page_id, live_data_keys: live_data_keys}}} = assigns
    live_data = Map.take(assigns, live_data_keys)
    BeaconWeb.DataSource.page_title(site, page_id, live_data)
  end

  def render_meta_tags(assigns) do
    ~H"""
    <%= for meta_attributes <- BeaconWeb.DataSource.meta_tags(assigns) do %>
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

  defp compiled_page_meta_tags(assigns) do
    %{beacon: %{site: site, private: %{page_id: page_id}}} = assigns
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

  defp compiled_layout_meta_tags(assigns) do
    %{beacon: %{site: site, private: %{layout_id: layout_id}}} = assigns
    %{meta_tags: meta_tags} = compiled_layout_assigns(site, layout_id)
    meta_tags
  end

  defp render_schema(assigns) do
    %{beacon: %{site: site, private: %{page_id: page_id}}} = assigns
    %{raw_schema: raw_schema} = compiled_page_assigns(site, page_id)

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

  def render_resource_links(assigns) do
    resource_links = layout_resource_links(assigns) || []
    assigns = assign(assigns, :resource_links, resource_links)

    ~H"""
    <%= for attr <- @resource_links do %>
      <link {attr} />
    <% end %>
    """
  end

  defp layout_resource_links(%{layout_assigns: %{resource_links: resource_links}} = assigns) do
    assigns
    |> compiled_layout_resource_links()
    |> Map.merge(resource_links)
  end

  defp layout_resource_links(assigns) do
    compiled_layout_resource_links(assigns)
  end

  defp compiled_layout_resource_links(assigns) do
    %{beacon: %{site: site, private: %{layout_id: layout_id}}} = assigns
    %{resource_links: resource_links} = compiled_layout_assigns(site, layout_id)
    resource_links
  end
end
