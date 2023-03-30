defmodule BeaconWeb.Admin.HomeLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Authorization

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin
    </.header>

    <.link :if={Authorization.authorized?(@agent, :index, %{mod: :admin})} navigate={beacon_admin_path(@socket, "/pages")}>
      <.button>Pages</.button>
    </.link>

    <.link :if={Authorization.authorized?(@agent, :index, %{mod: :admin})} navigate={beacon_admin_path(@socket, "/media_library")}>
      <.button>Media Library</.button>
    </.link>
    """
  end
end
