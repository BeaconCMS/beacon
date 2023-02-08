defmodule BeaconWeb.Layouts do
  @moduledoc false

  use BeaconWeb, :html
  require Logger

  embed_templates "layouts/*"

  # Load assets from host application
  # https://github.com/phoenixframework/phoenix_live_dashboard/blob/d0f776f4bc2ba119e52ec1e0f9f216962b9b6972/lib/phoenix/live_dashboard/layout_view.ex
  phoenix_path = Application.app_dir(:phoenix, "priv/static/phoenix.js")
  phoenix_html_path = Application.app_dir(:phoenix_html, "priv/static/phoenix_html.js")
  phoenix_live_view_path = Application.app_dir(:phoenix_live_view, "priv/static/phoenix_live_view.js")
  beacon_js_path = Path.join(__DIR__, "../../../dist/js/app.js")
  beacon_admin_css_path = Path.join(__DIR__, "../../../dist/css/admin.css")

  @external_resource phoenix_path
  @external_resource phoenix_html_path
  @external_resource phoenix_live_view_path
  @external_resource beacon_js_path
  @external_resource beacon_admin_css_path

  @app_js """
  #{File.read!(phoenix_html_path) |> String.replace("//# sourceMappingURL=", "// ")}
  #{File.read!(phoenix_path) |> String.replace("//# sourceMappingURL=", "// ")}
  #{File.read!(phoenix_live_view_path) |> String.replace("//# sourceMappingURL=", "// ")}
  #{File.read!(beacon_js_path)}
  """
  def live_socket_path(conn) do
    conn.private.beacon.live_socket_path
  end

  def render("app.js", _assigns) do
    @app_js
  end

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

  def render_dynamic_layout(%{__dynamic_layout_id__: layout_id, __site__: site} = assigns) do
    module = Beacon.Loader.layout_module_for_site(site)
    Beacon.Loader.call_function_with_retry(module, :render, [layout_id, assigns])
  end

  def page_title(%{layout_assigns: %{page_title: page_title}}), do: page_title

  def page_title(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{title: title} = compiled_layout_assigns(site, layout_id)
    title
  end

  def page_title(_) do
    Logger.warning("No page title set")
    ""
  end

  def merge_meta_tags(assigns) do
    site_meta_tags = site_get_meta_tags()

    layout_meta_tags = layout_get_meta_tags(assigns)

    page_meta_tags = page_get_meta_tags(assigns)

    page_meta_tags
    |> merge_tags_and_filter_out_attr_value(layout_meta_tags, "csrf-token")
    |> merge_tags(site_meta_tags)
  end

  defp merge_tags_and_filter_out_attr_value(tags1, tags2, attr_filter) do
    merge_tags(tags1, tags2)
    |> Enum.filter(fn
      [{_, value}, _] ->
        value !== attr_filter

      _ ->
        true
    end)
  end

  defp merge_tags(tags1, tags2) do
    Enum.concat(tags1, tags2)
  end

  defp join_tag_string(meta_tags) do
    Enum.map_join(meta_tags, "\n", fn
      [{attr_type, key}] ->
        ~s(<meta #{attr_type}="#{key}">)

      [{attr_type, key} | attrs] ->
        attr_string =
          Enum.map_join(attrs, " ", fn {attr_type, key} ->
            ~s(#{attr_type}="#{key}")
          end)

        ~s(<meta #{attr_type}="#{key}" #{attr_string}>)
    end)
  end

  def meta_tags(%{__dynamic_page_id__: _, __site__: _} = assigns) do
    {:safe, meta_tags_unsafe(assigns)}
  end

  def meta_tags(_), do: ""

  def meta_tags_unsafe(assigns) do
    meta_tags = merge_meta_tags(assigns)

    unless Enum.empty?(meta_tags) do
      join_tag_string(meta_tags)
    else
      ""
    end
  end

  def site_get_meta_tags do
    Beacon.default_site_meta_tags()
  end

  def page_get_meta_tags(%{page_assigns: %{meta_tags: meta_tags}} = assigns) do
    assigns
    |> compiled_page_meta_tags()
    |> Map.merge(meta_tags)
  end

  def page_get_meta_tags(assigns) do
    compiled_page_meta_tags(assigns)
  end

  defp compiled_page_meta_tags(%{__dynamic_page_id__: page_id, __site__: site}) do
    %{meta_tags: page_compiled_meta_tags} = compiled_page_assigns(site, page_id)
    page_compiled_meta_tags
  end

  defp compiled_page_assigns(site, page_id) do
    site
    |> Beacon.Loader.page_module_for_site()
    |> Beacon.Loader.call_function_with_retry(:page_assigns, [page_id])
  end

  def layout_get_meta_tags(%{layout_assigns: %{meta_tags: meta_tags}} = assigns) do
    assigns
    |> compiled_layout_meta_tags()
    |> Map.merge(meta_tags)
  end

  def layout_get_meta_tags(assigns) do
    compiled_layout_meta_tags(assigns)
  end

  defp compiled_layout_meta_tags(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{meta_tags: compiled_meta_tags} = compiled_layout_assigns(site, layout_id)
    compiled_meta_tags
  end

  defp compiled_layout_assigns(site, layout_id) do
    site
    |> Beacon.Loader.layout_module_for_site()
    |> Beacon.Loader.call_function_with_retry(:layout_assigns, [layout_id])
  end

  def dynamic_layout?(%{__dynamic_layout_id__: _}), do: true
  def dynamic_layout?(_), do: false

  def stylesheet_tag(%{__dynamic_layout_id__: _, __site__: site}) do
    module = Beacon.Loader.stylesheet_module_for_site(site)

    stylesheet_tag = Beacon.Loader.call_function_with_retry(module, :render, [])
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
