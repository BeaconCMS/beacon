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
    site = site(conn)
    router = router(conn)
    prefix = router.__beacon_scoped_prefix_for_site__(site)

    hash =
      cond do
        asset == :css -> Beacon.RuntimeCSS.current_hash(site)
        asset == :js -> Beacon.RuntimeJS.current_hash(site)
      end

    path = Beacon.Router.sanitize_path("#{prefix}/__beacon_assets__/#{asset}-#{hash}")
    Phoenix.VerifiedRoutes.unverified_path(conn, router, path)
  end

  defp site(%{assigns: %{beacon: %{site: site}}}), do: site

  defp site(_site) do
    Logger.error("Failed to find site to serve assets")
    nil
  end

  defp router(%Plug.Conn{private: %{phoenix_router: router}}), do: router
  defp router(%Phoenix.LiveView.Socket{router: router}), do: router

  @doc false
  def render_dynamic_layout(assigns) do
    %{beacon: %{site: site, private: %{layout_id: layout_id}}} = assigns

    case Beacon.RuntimeRenderer.render_layout(site, layout_id, assigns) do
      {:ok, rendered} ->
        rendered

      {:error, :not_found} ->
        require Logger
        Logger.error("[Beacon] Layout #{layout_id} not found in ETS for site #{site}")
        assigns.inner_content
    end
  end

  @doc """
  Returns the path to the live socket defined in the site configuration.
  """
  def live_socket_path(assigns) do
    %{beacon: %{site: site}} = assigns
    Beacon.Config.fetch!(site).live_socket_path
  end

  @doc """
  Returns the resolved page title.

  Page titles may use snippets to render dynamic content.
  This function will resolve such snippets.
  """
  def render_page_title(assigns) do
    %{beacon: %{site: site, page: %{title: title, path: path}, private: %{page_id: page_id}}} = assigns

    page_assigns = %{site: site, id: page_id, path: path, title: title}

    case Beacon.Content.render_snippet(title, %{page: page_assigns, data: assigns}) do
      {:ok, rendered_title} -> rendered_title
      {:error, _} -> title
    end
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
    layout_meta_tags = layout_meta_tags(assigns) || []

    case assigns do
      %{beacon_meta_tags: override_tags} when is_list(override_tags) ->
        (override_tags ++ layout_meta_tags)
        |> Enum.reject(&(&1["name"] == "csrf-token"))

      _ ->
        page_meta_tags = page_meta_tags(assigns) || []

        (page_meta_tags ++ layout_meta_tags)
        |> Enum.reject(&(&1["name"] == "csrf-token"))
        |> Kernel.++(Beacon.Content.default_site_meta_tags())
    end
  end

  defp page_meta_tags(%{beacon: %{site: site, private: %{page_id: page_id}}}) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    manifest.meta_tags || []
  end

  defp layout_meta_tags(%{beacon: %{site: site, private: %{layout_id: layout_id}}}) do
    case Beacon.RuntimeRenderer.fetch_layout_manifest(site, layout_id) do
      {:ok, manifest} -> manifest.meta_tags || []
      :error -> []
    end
  end

  defp layout_meta_tags(_assigns), do: []

  @doc """
  Renders the Schema.org data defined in the current page.
  """
  def render_schema(%{beacon: %{site: site, private: %{page_id: page_id}}} = assigns) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    raw_schema = manifest.raw_schema || []

    is_empty = fn rs -> rs |> Enum.map(&Map.values/1) |> List.flatten() == [] end

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
    resource_links =
      case assigns do
        %{beacon: %{site: site, private: %{layout_id: layout_id}}} ->
          case Beacon.RuntimeRenderer.fetch_layout_manifest(site, layout_id) do
            {:ok, manifest} -> manifest.resource_links || []
            :error -> []
          end

        _ ->
          []
      end

    assigns = assign(assigns, :resource_links, resource_links)

    ~H"""
    <%= for attr <- @resource_links do %>
      <link {attr} />
    <% end %>
    """
  end
end
