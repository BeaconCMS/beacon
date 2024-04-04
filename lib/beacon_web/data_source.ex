defmodule BeaconWeb.DataSource do
  @moduledoc false

  require Logger

  def live_data(site, path_info, params \\ %{}) when is_atom(site) and is_list(path_info) and is_map(params) do
    site
    |> Beacon.Loader.fetch_live_data_module()
    |> Beacon.apply_mfa(:live_data, [path_info, params])
  end

  def page_title(site, page_id, live_data) do
    page =
      site
      |> Beacon.Loader.fetch_page_module(page_id)
      |> Beacon.apply_mfa(:page_assigns, [])

    case Beacon.Content.render_snippet(page.title, %{page: page, live_data: live_data}) do
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
    %{__site__: site, __dynamic_page_id__: page_id} = assigns

    page =
      site
      |> Beacon.Loader.fetch_page_module(page_id)
      |> Beacon.apply_mfa(:page_assigns, [])

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
