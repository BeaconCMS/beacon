defmodule BeaconWeb.Admin.MediaLibraryLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Authorization
  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Asset

  on_mount {BeaconWeb.Admin.Hooks.Authorized, {:media_library, :index}}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:authn_context, %{mod: :media_library})
      |> assign(assets: list_assets(), search: "")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    if Authorization.authorized?(assigns.agent, assigns.live_action, assigns.authn_context) do
      search = Map.get(params, "search", "")

      socket =
        socket
        |> assign(:search, search)
        |> apply_action(assigns.live_action, params)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
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

  defp apply_action(socket, :show, %{"id" => id}) do
    asset = MediaLibrary.get_asset_by(id: id)

    socket
    |> assign(:page_title, "Upload")
    |> assign(:asset, asset)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: assigns} = socket) do
    if Authorization.authorized?(assigns.agent, :delete, Map.put(assigns.authn_context, :resource_id, id)) do
      asset = MediaLibrary.get_asset_by(id: id)
      {:ok, _} = MediaLibrary.soft_delete(asset)

      path = beacon_admin_path(socket, "/media_library", search: socket.assigns.search)
      socket = push_patch(socket, to: path)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("search", %{"search" => search}, %{assigns: assigns} = socket) do
    if Authorization.authorized?(assigns.agent, :search, assigns.authn_context) do
      path = beacon_admin_path(socket, "/media_library", search: search)
      socket = push_patch(socket, to: path)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp list_assets do
    MediaLibrary.list_assets()
  end
end
