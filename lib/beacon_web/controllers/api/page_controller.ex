defmodule BeaconWeb.API.PageController do
  use BeaconWeb, :controller

  alias Beacon.Content

  action_fallback BeaconWeb.API.FallbackController

  def show(conn, %{"id" => id}) do
    page = Content.get_page!(id)
    render(conn, :show, page: page)
  end
end
