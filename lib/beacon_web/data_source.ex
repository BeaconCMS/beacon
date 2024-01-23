defmodule BeaconWeb.DataSource do
  @moduledoc false

  def page_title(assigns) do
    page =
      assigns.__dynamic_page_id__
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry(:page_assigns, [])

    title = BeaconWeb.Layouts.page_title(assigns)

    case Beacon.Content.render_snippet(title, %{page: page, live_data: assigns.beacon_live_data}) do
      {:ok, page_title} -> page_title
      :error -> raise Beacon.SnippetError, message: "failed to interpolate page title"
    end
  end

  def meta_tags(assigns) do
    page =
      assigns.__dynamic_page_id__
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry(:page_assigns, [])

    assigns
    |> BeaconWeb.Layouts.meta_tags()
    |> List.wrap()
    |> Enum.map(&interpolate_meta_tag(&1, %{page: page, live_data: assigns.beacon_live_data}))
  end

  defp interpolate_meta_tag(meta_tag, values) when is_map(meta_tag) do
    Map.new(meta_tag, &interpolate_meta_tag_attribute(&1, values))
  end

  defp interpolate_meta_tag_attribute({key, text}, values) when is_binary(text) do
    case Beacon.Content.render_snippet(text, values) do
      {:ok, new_text} -> {key, new_text}
      :error -> raise Beacon.SnippetError, message: "failed to interpolate meta tags"
    end
  end
end
