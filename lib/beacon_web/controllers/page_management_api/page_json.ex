defmodule BeaconWeb.PageManagementApi.PageJSON do
  def index(%{pages: pages}) do
    %{data: for(page <- pages, do: data(page))}
  end

  def show(%{page: page}) do
    %{data: data(page)}
  end

  defp data(page) do
    %{
      id: page.id,
      layout_id: page.layout_id,
      pending_layout_id: page.pending_layout_id,
      path: page.path,
      site: page.site,
      template: page.template,
      pending_template: page.pending_template,
      version: page.version
    }
  end
end
