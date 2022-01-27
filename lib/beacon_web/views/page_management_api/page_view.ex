defmodule BeaconWeb.PageManagementApi.PageView do
  use BeaconWeb, :view
  alias BeaconWeb.PageManagementApi.PageView

  def render("index.json", %{pages: pages}) do
    %{data: render_many(pages, PageView, "page.json")}
  end

  def render("show.json", %{page: page}) do
    %{data: render_one(page, PageView, "page.json")}
  end

  def render("page.json", %{page: page}) do
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
