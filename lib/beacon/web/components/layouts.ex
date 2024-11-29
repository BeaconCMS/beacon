defmodule Beacon.Web.Layouts do
  @moduledoc """
  Core layouts.

  These functions are mostly used internally by Beacon but you can override the
  root layout in `beacon_site` so you should use the functions in this
  module to properly build your custom root layout to avoid breaking
  Beacon functionality.

  See https://github.com/BeaconCMS/beacon/blob/main/lib/beacon/web/components/layouts/runtime.html.heex for reference.

  """

  use Beacon.Web, :html
  require Logger

  embed_templates "layouts/*"

  @doc """
  Returns the path to the route that serves CSS and JS assets.
  """
  # TODO: style nonce
  def asset_path(conn, asset) when asset in [:css, :js] do
    %{assigns: %{beacon: %{site: site}}} = conn
    prefix = router(conn).__beacon_scoped_prefix_for_site__(site)

    hash =
      cond do
        asset == :css -> Beacon.RuntimeCSS.current_hash(site)
        asset == :js -> Beacon.RuntimeJS.current_hash()
      end

    path = Beacon.Router.sanitize_path("#{prefix}/__beacon_assets__/#{asset}-#{hash}")
    Phoenix.VerifiedRoutes.unverified_path(conn, conn.private.phoenix_router, path)
  end

  defp router(%Plug.Conn{private: %{phoenix_router: router}}), do: router
  defp router(%Phoenix.LiveView.Socket{router: router}), do: router

  @doc false
  def render_dynamic_layout(assigns) do
    %{beacon: %{site: site, private: %{page_module: page_module}}} = assigns
    %{site: ^site, layout_id: layout_id} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site, :layout_id]])
    layout_module = Beacon.Loader.fetch_layout_module(site, layout_id)
    Beacon.apply_mfa(site, layout_module, :render, [assigns])
  end

  @doc """
  Returns the path to the live socket defined in the site configuration.
  """
  def live_socket_path(assigns) do
    %{beacon: %{site: site}} = assigns
    Beacon.Config.fetch!(site).live_socket_path
  end

  defp compiled_page_assigns(site, page_id) do
    Beacon.apply_mfa(site, Beacon.Loader.fetch_page_module(site, page_id), :page_assigns, [])
  end

  defp compiled_layout_assigns(site, layout_id) do
    Beacon.apply_mfa(site, Beacon.Loader.fetch_layout_module(site, layout_id), :layout_assigns, [])
  end

  @doc """
  Returns the resolved page title.

  Page titles may use snippets to render dynamic content.
  This function will resolve such snippets.
  """
  def render_page_title(assigns) do
    %{beacon: %{page: %{title: title}}} = assigns
    title
  end

  @doc """
  Renders all `<meta>` tags defined in the current page.
  """
  def render_meta_tags(assigns) do
    ~H"""
    <%= for meta_attributes <- Beacon.Web.DataSource.meta_tags(assigns) do %>
      <meta {meta_attributes} />
    <% end %>
    """
  end

  @doc false
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
    %{beacon: %{site: site, private: %{page_module: page_module}}} = assigns
    %{site: ^site, id: page_id} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site, :id]])
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
    %{beacon: %{site: site, private: %{page_module: page_module}}} = assigns
    %{site: ^site, layout_id: layout_id} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site, :layout_id]])
    %{meta_tags: meta_tags} = compiled_layout_assigns(site, layout_id)
    meta_tags
  end

  @doc """
  Renders the Schema.org data defined in the current page.
  """
  def render_schema(assigns) do
    %{beacon: %{site: site, private: %{page_module: page_module}}} = assigns
    %{site: ^site, id: page_id} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site, :id]])
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

  @doc """
  Renders all resource `<link>` tags defined in the current layout.
  """
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
    %{beacon: %{site: site, private: %{page_module: page_module}}} = assigns
    %{site: ^site, layout_id: layout_id} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site, :layout_id]])
    %{resource_links: resource_links} = compiled_layout_assigns(site, layout_id)
    resource_links
  end
end
