defmodule BeaconWeb.Layouts do
  @moduledoc false

  use BeaconWeb, :html
  require Logger

  embed_templates "layouts/*"

  # Load assets from host application
  # https://github.com/phoenixframework/phoenix_live_dashboard/blob/d0f776f4bc2ba119e52ec1e0f9f216962b9b6972/lib/phoenix/live_dashboard/layout_view.ex

  beacon_admin_css_path = Path.join(__DIR__, "../../../dist/css/admin.css")
  @external_resource beacon_admin_css_path

  # TODO: style nonce
  def render("app.css", %{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{runtime_css: runtime_css} = compiled_layout_assigns(site, layout_id)
    runtime_css
  end

  def render("app.css", _assigns) do
    ""
  end

  if Code.ensure_loaded?(Mix.Project) and Mix.env() == :dev do
    def render("admin.css", _assigns) do
      """
      <link phx-track-static rel="stylesheet" href="/dev/assets/admin.css" />
      """
    end
  else
    @admin_css File.read!(beacon_admin_css_path)
    def render("admin.css", _assigns) do
      """
      <style>
      #{@admin_css}
      </style>
      """
    end
  end

  if Code.ensure_loaded?(Mix.Project) and Mix.env() == :dev do
    def app_js_path do
      "/beacon_static/beaconcms.js"
    end
  else
    def app_js_path do
      "/beacon_static/beaconcms.min.js"
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

  def page_title(%{__dynamic_page_id__: _, __site__: site, __live_path__: path} = assigns) do
    params = Map.drop(assigns.conn.params, ["path"])
    current_page_title = fetch_page_title(assigns)
    Beacon.DataSource.page_title(site, %{path: path, params: params, page_title: current_page_title, beacon_live_data: assigns.beacon_live_data})
  end

  def page_title(assigns), do: fetch_page_title(assigns)

  @doc false
  def fetch_page_title(%{__dynamic_layout_id__: layout_id, __dynamic_page_id__: page_id, __site__: site}) do
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

  def fetch_page_title(_), do: missing_page_title()

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
    current_meta_tags = meta_tags(assigns)

    assigns =
      assign(
        assigns,
        :meta_tags,
        Beacon.DataSource.meta_tags(site, %{path: path, params: params, meta_tags: current_meta_tags, beacon_live_data: assigns.beacon_live_data})
      )

    ~H"""
    <%= for meta_attributes <- @meta_tags do %>
      <meta {meta_attributes} />
    <% end %>
    """
  end

  def render_meta_tags(assigns) do
    assigns = assign(assigns, :meta_tags, meta_tags(assigns))

    ~H"""
    <%= for meta_attributes <- @meta_tags do %>
      <meta {meta_attributes} />
    <% end %>
    """
  end

  def meta_tags(%{__dynamic_page_id__: _, __site__: _} = assigns) do
    page_meta_tags = page_meta_tags(assigns) || []
    layout_meta_tags = layout_meta_tags(assigns) || []

    (page_meta_tags ++ layout_meta_tags)
    |> Enum.reject(&(&1["name"] == "csrf-token"))
    |> Kernel.++(Beacon.default_site_meta_tags())
  end

  def meta_tags(_), do: []

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
