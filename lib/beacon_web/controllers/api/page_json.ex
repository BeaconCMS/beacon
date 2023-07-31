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
    %{
      id: page.id,
      layout_id: page.layout_id,
      path: page.path,
      site: page.site,
      template: page.template,
      format: page.format,
      components: []
    }
  end
end
