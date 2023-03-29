defmodule BeaconWeb.Admin.HomeLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Authorization
  alias Beacon.MediaLibrary.Asset
  alias Beacon.Pages.Page

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin
    </.header>

    <%= if Authorization.authorized?(@agent, :index, %Page{}) do %>
      <.link navigate={beacon_admin_path(@socket, "/pages")}>
        <.button>Pages</.button>
      </.link>
    <% end %>

    <%= if Authorization.authorized?(@agent, :index, %Asset{}) do %>
      <.link navigate={beacon_admin_path(@socket, "/media_library")}>
        <.button>Media Library</.button>
      </.link>
    <% end %>
    """
  end
end
