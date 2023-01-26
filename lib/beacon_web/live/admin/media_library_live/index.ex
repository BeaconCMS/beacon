defmodule BeaconWeb.Admin.MediaLibraryLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Admin.MediaLibrary
  alias Beacon.Admin.MediaLibrary.Asset

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, assets: list_assets(), search: "")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search = Map.get(params, "search", "")

    socket =
      socket
      |> assign(:search, search)
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, %{"search" => search}) when search not in ["", nil] do
    assets = MediaLibrary.search(search)

    socket
    |> assign(assets: assets, search: search, page_title: search)
    |> assign(:asset, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:assets, list_assets())
    |> assign(:page_title, "Media Library")
    |> assign(:asset, nil)
  end

  defp apply_action(socket, :upload, _params) do
    socket
    |> assign(:page_title, "Upload")
    |> assign(:asset, %Asset{})
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    asset = MediaLibrary.get_asset!(id)
    {:ok, _} = MediaLibrary.soft_delete_asset(asset)

    path = beacon_admin_path(socket, "/media_library", search: socket.assigns.search)
    socket = push_patch(socket, to: path)

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => search}, socket) do
    path = beacon_admin_path(socket, "/media_library", search: search)
    socket = push_patch(socket, to: path)
    {:noreply, socket}
  end

  defp list_assets do
    MediaLibrary.list_assets()
  end
end
