defmodule BeaconWeb.API.PageJSON do
  @moduledoc false

  alias Beacon.Content.Layout
  alias Beacon.Content.Page
  alias Beacon.Template.HEEx.JSONEncoder

  @doc """
  Renders a list of pages.
  """
  def index(%{pages: pages}) do
    %{data: for(page <- pages, do: data(page))}
  end

  @doc """
  Renders a single page.
  """
  def show(%{page: page}) do
    %{data: data(page)}
  end

  defp data(%Page{} = page) do
    path_info = for segment <- String.split(page.path, "/"), segment != "", do: segment
    live_data = BeaconWeb.DataSource.live_data(page.site, path_info, %{})

    %{
      id: page.id,
      layout_id: page.layout_id,
      path: page.path,
      site: page.site,
      template: page.template,
      format: page.format,
      ast: page_ast(page, live_data)
    }
    |> maybe_include_layout(page, live_data)
  end

  defp page_ast(page, live_data) do
    case JSONEncoder.encode(page.site, page.template, %{beacon_live_data: live_data}) do
      {:ok, ast} -> ast
      _ -> []
    end
  end

  defp maybe_include_layout(%{template: page_template} = data, %Page{layout: %Layout{} = layout}, live_data) do
    layout =
      layout
      |> Map.from_struct()
      |> Map.drop([:__meta__])
      |> Map.put(:ast, layout_ast(layout, page_template, live_data))

    Map.put(data, :layout, layout)
  end

  defp maybe_include_layout(data, _page, _beacon_live_data), do: data

  # TODO: cache layout ast instead of recomputing for every page
  defp layout_ast(layout, page_template, live_data) do
    case JSONEncoder.encode(layout.site, layout.template, %{inner_content: page_template, beacon_live_data: live_data}) do
      {:ok, ast} -> ast
      _ -> []
    end
  end
end
