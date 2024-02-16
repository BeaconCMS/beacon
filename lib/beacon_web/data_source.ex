defmodule BeaconWeb.DataSource do
  @moduledoc false

  require Logger

  def live_data(site, path, params) when is_atom(site) do
    data_source_module = Beacon.Loader.data_source_module_for_site(site)

    if Code.loaded?(data_source_module) do
      data_source_module.live_data(path, params)
    else
      Logger.warning("""
      data source module #{data_source_module} for site #{site} and path #{path}  is not loaded

      returning empty live data for that page
      """)

      %{}
    end
  end

  def page_title(assigns) do
    page =
      assigns.__dynamic_page_id__
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry!(:page_assigns, [])

    title = BeaconWeb.Layouts.page_title(assigns)

    case Beacon.Content.render_snippet(title, %{page: page, live_data: assigns.beacon_live_data}) do
      {:ok, page_title} ->
        page_title

      {:error, error} ->
        Logger.error("""
        failed to interpolate page title variables, fallbacking to original page title

        Site: #{page.site}
        Page path: #{page.path}

        Got: #{inspect(error)}

        """)

        page.title
    end
  end

  def meta_tags(assigns) do
    page =
      assigns.__dynamic_page_id__
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry!(:page_assigns, [])

    assigns
    |> BeaconWeb.Layouts.meta_tags()
    |> List.wrap()
    |> Enum.map(&interpolate_meta_tag(&1, %{page: page, live_data: assigns.beacon_live_data}))
  end

  defp interpolate_meta_tag(meta_tag, values) when is_map(meta_tag) do
    Map.new(meta_tag, &interpolate_meta_tag_attribute(&1, values))
  end

  # TODO: maybe remove invalid meta tag instead of raising?
  defp interpolate_meta_tag_attribute({key, text}, values) when is_binary(text) do
    case Beacon.Content.render_snippet(text, values) do
      {:ok, new_text} -> {key, new_text}
      {:error, error} -> raise error
    end
  end
end
