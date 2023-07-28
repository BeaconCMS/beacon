defmodule BeaconWeb.API.PageController do
  use BeaconWeb, :controller
  alias Beacon.Content
  alias Beacon.Repo

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, _params) do
    pages =
      :dev
      |> Content.list_pages()

    render(conn, :index, pages: pages)
  end

  def show(conn, %{"id" => id}) do
    page = Content.get_page!(id)
    render(conn, :show, page: page)
  end

  def update(conn, %{"id" => id} = map) do
    page = Content.get_page!(id)
    data = Map.delete(map, "id")
    {:ok, page} = Content.update_page(page, data)
    render(conn, :show, page: page)
  end
end
