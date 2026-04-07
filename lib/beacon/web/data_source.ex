defmodule Beacon.Web.DataSource do
  @moduledoc false

  require Logger

  def live_data(site, path_info, query_params \\ %{})

  def live_data(site, path_info, query_params) when is_atom(site) and is_list(path_info) and is_map(query_params) do
    path = "/" <> Enum.join(path_info, "/")

    case Beacon.RuntimeRenderer.lookup_page(site, path) do
      {:ok, page_id} ->
        Beacon.RuntimeRenderer.evaluate_live_data(site, page_id, path_info, Map.drop(query_params, ["path"]))

      :error ->
        %{}
    end
  end

  def live_data(_site, _path_info, _query_params), do: %{}

  def page_title(%Beacon.Content.Page{} = page, live_data) do
    case live_data do
      %{beacon_page_title: override_title} when is_binary(override_title) ->
        override_title

      _ ->
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
  end

  def meta_tags(%{beacon: %{site: site, private: %{page_id: page_id, live_data_keys: live_data_keys}}} = assigns) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    page_assigns = %{site: site, id: page_id, path: manifest.path, title: manifest.title, description: manifest.description, meta_tags: manifest.meta_tags}
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

  defp page_assigns(%Beacon.Content.Page{} = page) do
    %{
      id: page.id,
      site: page.site,
      layout_id: page.layout_id,
      title: page.title,
      meta_tags: page.meta_tags,
      path: page.path,
      description: page.description,
      order: page.order,
      format: page.format,
      extra: page.extra
    }
  end
end
