defmodule Beacon.Web.API.PageJSON do
  @moduledoc false

  alias Beacon.Content.Layout
  alias Beacon.Content.Page
  alias Beacon.Template.HEEx.JSONEncoder
  alias Beacon.Web.BeaconAssigns

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
    live_data = Beacon.Web.DataSource.live_data(page.site, path_info, %{})
    beacon_assigns = BeaconAssigns.new(page.site, page, live_data, path_info, %{}, :admin)

    assigns =
      live_data
      |> Map.put(:beacon, beacon_assigns)
      # TODO: remove deprecated @beacon_live_data
      |> Map.put(:beacon_live_data, live_data)

    %{
      id: page.id,
      layout_id: page.layout_id,
      path: page.path,
      site: page.site,
      template: page.template,
      format: page.format,
      ast: page_ast(page, assigns)
    }
    |> maybe_include_layout(page, assigns)
  end

  defp page_ast(page, assigns) do
    case JSONEncoder.encode(page.site, page.template, assigns) do
      {:ok, ast} -> ast
      _ -> []
    end
  end

  defp maybe_include_layout(%{template: page_template} = data, %Page{layout: %Layout{} = layout}, assigns) do
    layout =
      layout
      |> Map.from_struct()
      |> Map.drop([:__meta__])
      |> Map.put(:ast, layout_ast(layout, page_template, assigns))

    Map.put(data, :layout, layout)
  end

  defp maybe_include_layout(data, _page, _assigns), do: data

  # TODO: cache layout ast instead of recomputing for every page
  defp layout_ast(layout, page_template, assigns) do
    assigns = Map.put(assigns, :inner_content, page_template)

    case JSONEncoder.encode(layout.site, layout.template, assigns) do
      {:ok, ast} -> ast
      _ -> []
    end
  end
end
