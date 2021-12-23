defmodule BeaconWeb.LayoutView do
  use BeaconWeb, :view

  require Logger

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def page_title(%{layout_assigns: %{page_title: page_title}}), do: page_title

  def page_title(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{title: title} = compiled_layout_assigns(site, layout_id)
    title
  end

  def page_title(_) do
    Logger.warn("No page title set")
    ""
  end

  # for dynamic pages
  def meta_tags(%{__dynamic_layout_id__: _, __site__: _} = assigns) do
    {:safe, meta_tags_unsafe(assigns)}
  end

  def meta_tags(_), do: ""

  def meta_tags_unsafe(assigns) do
    assigns
    |> get_meta_tags()
    |> Enum.map_join("\n", fn {key, value} ->
      # TODO: escape key/values here
      "    <meta property=\"#{key}\" content=\"#{value}\">"
    end)
  end

  # for non dynamic pages

  def get_meta_tags(%{layout_assigns: %{meta_tags: meta_tags}} = assigns) do
    assigns
    |> compiled_meta_tags()
    |> Map.merge(meta_tags)
  end

  def get_meta_tags(assigns) do
    compiled_meta_tags(assigns)
  end

  def dynamic_layout?(%{__dynamic_layout_id__: _}), do: true
  def dynamic_layout?(_), do: false

  defp compiled_meta_tags(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{meta_tags: compiled_meta_tags} = compiled_layout_assigns(site, layout_id)
    compiled_meta_tags
  end

  defp compiled_layout_assigns(site, layout_id) do
    module = Beacon.Loader.layout_module_for_site(site)

    Beacon.Loader.call_function_with_retry(module, :layout_assigns, [layout_id])
  end

  def stylesheet_tags(%{__dynamic_layout_id__: _, __site__: _} = assigns) do
    {:safe, stylesheet_tags_unsafe(assigns)}
  end

  def stylesheet_tags(_), do: ""

  def stylesheet_tags_unsafe(assigns) do
    assigns
    |> get_stylesheet_tags()
    |> Enum.map_join("\n", fn sheet ->
      # TODO: escape key/values here
      ~s(    <link rel="stylesheet" href="#{sheet}">)
    end)
  end

  # for non dynamic pages

  def get_stylesheet_tags(%{layout_assigns: %{stylesheet_tags: stylesheet_tags}} = assigns) do
    assigns
    |> compiled_stylesheet_tags()
    |> Map.merge(stylesheet_tags)
  end

  def get_stylesheet_tags(assigns) do
    compiled_stylesheet_tags(assigns)
  end

  defp compiled_stylesheet_tags(%{__dynamic_layout_id__: layout_id, __site__: site}) do
    %{stylesheets: compiled_stylesheet_tags} = compiled_layout_assigns(site, layout_id)
    compiled_stylesheet_tags
  end
end
