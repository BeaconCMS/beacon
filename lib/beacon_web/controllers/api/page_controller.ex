defmodule BeaconWeb.API.PageController do
  use BeaconWeb, :controller
  alias Beacon.Content
  alias Beacon.Content.Page

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, %{"site" => site}) do
    pages = Content.list_pages(site)
    render(conn, :index, pages: pages)
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"page_id" => page_id}) do
    page =
      case fetch_query_params(conn) do
        %{params: %{"include" => "layout"}} -> Content.get_page!(page_id, preloads: [:layout])
        _ -> Content.get_page!(page_id)
      end

    render(conn, :show, page: page)
  end

  def update(conn, %{"page_id" => page_id, "page" => page_params}) do
    page = Content.get_page!(page_id)

    with {:ok, %Page{} = page} <- Content.update_page(page, page_params) do
      render(conn, :show, page: page)
    end
  end
end
