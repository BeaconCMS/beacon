defmodule BeaconWeb.Admin.HomeLive.Index do
  use BeaconWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Admin
    </.header>

    <.link navigate="/beacon/admin/pages">
      <.button>Pages</.button>
    </.link>

    <.link navigate="/beacon/admin/media_library">
      <.button>Media Library</.button>
    </.link>
    """
  end
end
