defmodule BeaconWeb.AdminApi.LayoutController do
  use BeaconWeb, :controller

  alias Beacon.Content

  action_fallback BeaconWeb.FallbackController

  def show(conn, %{"id" => id}) do
    layout = Content.get_layout!(id)
    render(conn, :show, a_layout: layout)
  end
end
