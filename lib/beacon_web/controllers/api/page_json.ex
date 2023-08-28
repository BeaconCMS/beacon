defmodule BeaconWeb.API.PageJSON do
  @moduledoc false

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
    path = for segment <- String.split(page.path, "/"), segment != "", do: segment
    beacon_live_data = Beacon.DataSource.live_data(page.site, path, []) |> dbg
    {:ok, ast} = Beacon.Template.HEEx.JSONEncoder.encode(page.site, page.template, %{beacon_live_data: beacon_live_data})

    %{
      id: page.id,
      layout_id: page.layout_id,
      path: page.path,
      site: page.site,
      template: page.template,
      format: page.format,
      ast: ast
    }
  end
end
