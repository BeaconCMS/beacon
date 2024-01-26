defmodule BeaconWeb.API.PageJSON do
  @moduledoc false

  alias Beacon.Content.Layout
  alias Beacon.Content.Page

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
    %{
      id: page.id,
      layout_id: page.layout_id,
      path: page.path,
      site: page.site,
      template: page.template,
      format: page.format,
      ast: page_ast(page)
    }
    |> maybe_include_layout(page)
  end

  defp page_ast(page) do
    path = for segment <- String.split(page.path, "/"), segment != "", do: segment
    beacon_live_data = Beacon.DataSource.live_data(page.site, path, [])

    case Beacon.Template.HEEx.JSONEncoder.encode(page.site, page.template, %{beacon_live_data: beacon_live_data}) do
      {:ok, ast} -> ast
      _ -> []
    end
  end

  defp maybe_include_layout(%{template: page_template} = data, %Page{layout: %Layout{} = layout}) do
    layout =
      layout
      |> Map.from_struct()
      |> Map.drop([:__meta__])
      |> Map.put(:ast, layout_ast(layout, page_template))

    Map.put(data, :layout, layout)
  end

  defp maybe_include_layout(data, _page), do: data

  # TODO: cache layout ast instead of recomputing for every page
  defp layout_ast(layout, page_template) do
    {:ok, ast} = Beacon.Template.HEEx.JSONEncoder.encode(layout.site, layout.template, %{inner_content: page_template})
    ast
  end
end
