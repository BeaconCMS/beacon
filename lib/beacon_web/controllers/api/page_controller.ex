defmodule BeaconWeb.API.PageController do
  use BeaconWeb, :controller
  alias Beacon.Content
  alias Beacon.Repo

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, _params) do
    pages = 
      :dev
      |> Content.list_pages()
      |> Repo.preload(:components)
    render(conn, :index, pages: pages)
  end

  def show(conn, %{"id" => id}) do
    page = Content.get_page!(id)
    render(conn, :show, page: page)
  end
end
