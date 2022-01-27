defmodule BeaconWeb.PageManagementApi.LayoutView do
  use BeaconWeb, :view
  alias BeaconWeb.PageManagementApi.LayoutView

  def render("index.json", %{layouts: layouts}) do
    %{data: render_many(layouts, LayoutView, "layout.json", as: :a_layout)}
  end

  def render("show.json", %{a_layout: layout}) do
    %{data: render_one(layout, LayoutView, "layout.json", as: :a_layout)}
  end

  def render("layout.json", %{a_layout: layout}) do
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
