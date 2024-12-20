defmodule Beacon.Web.DataSource do
  @moduledoc false

  require Logger

  def live_data(site, path_info, query_params) when is_atom(site) and is_list(path_info) and is_map(query_params) do
    Beacon.apply_mfa(site, Beacon.Loader.fetch_live_data_module(site), :live_data, [path_info, query_params])
  end

  def live_data(_site, _path_info, _query_params), do: %{}

  def page_title(%Beacon.Content.Page{} = page, live_data) do
    %{path: path, title: title} = page_assigns = page_assigns(page)

    with {:ok, page_title} <- Beacon.Content.render_snippet(title, %{page: page_assigns, live_data: live_data}) do
      page_title
    else
      {:error, error} ->
        Logger.error("""
        failed to interpolate page title variables

        will return the original unmodified page title

        site: #{page.site}
        title: #{title}
        page path: #{path}

        Got:

          #{inspect(error)}

        """)

        title
    end
  end

  # TODO: revisit this logic to evaluate meta_tags for unpublished pages
  def meta_tags(assigns) do
    %{beacon: %{site: site, private: %{page_module: page_module, live_data_keys: live_data_keys}}} = assigns
    %{site: ^site} = page_assigns = Beacon.apply_mfa(site, page_module, :page_assigns, [])

    live_data = Map.take(assigns, live_data_keys)

    assigns
    |> Beacon.Web.Layouts.meta_tags()
    |> List.wrap()
    |> Enum.map(&interpolate_meta_tag(&1, %{page: page_assigns, live_data: live_data}))
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

  # return the page assigns from unpublished page assigns,
  # either saved in the database or page in-memory (for new pages)
  # this fallback is here mostly to support  beacon_live_admin visual editor,
  # which makes use of the `@beacon` assign when creating or editing pages
  defp page_assigns(%Beacon.Content.Page{id: nil} = page) do
    unpublished_page_assigns(page)
  end

  defp page_assigns(%Beacon.Content.Page{} = page) do
    Beacon.apply_mfa(page.site, Beacon.Loader.fetch_page_module(page.site, page.id), :page_assigns, [])
  rescue
    _ -> unpublished_page_assigns(page)
  end

  defp unpublished_page_assigns(page) do
    %{
      id: page.id,
      site: page.site,
      layout_id: page.layout_id,
      title: page.title,
      meta_tags: page.meta_tags,
      raw_schema: Beacon.Loader.Page.interpolate_raw_schema(page),
      path: page.path,
      description: page.description,
      order: page.order,
      format: page.format,
      extra: page.extra
    }
  end
end
