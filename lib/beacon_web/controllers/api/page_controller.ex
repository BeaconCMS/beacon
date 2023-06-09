defmodule BeaconWeb.API.PageController do
  use BeaconWeb, :controller

  alias Beacon.Pages

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, _params) do
    pages = Pages.list_pages()
    render(conn, :index, pages: pages)
  end

  def show(conn, %{"id" => id}) do
    page = Pages.get_page!(id)
    render(conn, :show, page: page)
  end
end
