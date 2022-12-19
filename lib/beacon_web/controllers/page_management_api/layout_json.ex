defmodule BeaconWeb.PageManagementApi.LayoutJSON do
  def index(%{layouts: layouts}) do
    %{data: for(layout <- layouts, do: data(layout))}
  end

  def show(%{layout: layout}) do
    %{data: data(layout)}
  end

  defp data(layout) do
    %{
      id: layout.id,
      body: layout.body,
      meta_tags: layout.meta_tags,
      site: layout.site,
      stylesheet_urls: layout.stylesheet_urls,
      title: layout.title
    }
  end
end
