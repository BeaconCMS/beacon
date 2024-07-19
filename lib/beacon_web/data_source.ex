defmodule BeaconWeb.DataSource do
  @moduledoc false

  require Logger

  def live_data(site, path_info, params \\ %{}) when is_atom(site) and is_list(path_info) and is_map(params) do
    site
    |> Beacon.Loader.fetch_live_data_module()
    |> Beacon.apply_mfa(:live_data, [path_info, params])
  end

  # TODO: revisit this logic to evaluate page_title for unpublished pages
  def page_title(site, page_id, live_data) do
    page_assigns = page_assigns(site, page_id)

    with {:ok, page_assigns} <- page_assigns,
         {:ok, page_title} <- Beacon.Content.render_snippet(page_assigns.title, %{page: page_assigns, live_data: live_data}) do
      page_title
    else
      {:error, :page_module_not_found} ->
        ""

      {:error, error} ->
        {path, original_title} =
          case page_assigns do
            {:ok, page_assigns} -> {page_assigns.path, page_assigns.title}
            _ -> {nil, ""}
          end

        Logger.error("""
        failed to interpolate page title variables

        will return the original unmodified page title

        site: #{site}
        page path: #{path}

        Got:

          #{inspect(error)}

        """)

        original_title
    end
  end

  # TODO: revisit this logic to evaluate meta_tags for unpublished pages
  def meta_tags(assigns) do
    %{beacon: %{page: page, private: %{page_module: page_module, live_data_keys: live_data_keys}}} = assigns
    %{site: site, id: page_id} = Beacon.apply_mfa(page_module, :page_assigns, [[:site, :id]])
    live_data = Map.take(assigns, live_data_keys)

    case page_assigns(site, page_id) do
      {:error, _} ->
        Logger.error("""
        failed to interpolate page meta tags, returning empty list of meta tags

        Site: #{site}
        Page path: #{page.path}

        """)

        []

      {:ok, page_assigns} ->
        assigns
        |> BeaconWeb.Layouts.meta_tags()
        |> List.wrap()
        |> Enum.map(&interpolate_meta_tag(&1, %{page: page_assigns, live_data: live_data}))
    end
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

  # only published pages will have the title evaluated,
  # which is what we need for sites to work properly but
  # the page builder could use this data as well
  defp page_assigns(site, page_id) do
    page_module = Beacon.Loader.fetch_page_module(site, page_id)

    if :erlang.module_loaded(page_module) do
      {:ok, Beacon.apply_mfa(page_module, :page_assigns, [])}
    else
      {:error, :page_module_not_found}
    end
  end
end
