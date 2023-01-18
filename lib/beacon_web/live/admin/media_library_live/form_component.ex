defmodule BeaconWeb.Admin.MediaLibraryLive.FormComponent do
  use BeaconWeb, :live_component

  alias Beacon.Admin.MediaLibrary

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>Upload</.header>

      <.form for={:assets} id="asset-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <.live_file_input upload={@uploads.asset} tabindex="0" />
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{asset: asset} = assigns, socket) do
    changeset = MediaLibrary.change_asset(asset)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> allow_upload(:asset,
       auto_upload: true,
       progress: &handle_progress/3,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 10
     )}
  end

  defp handle_progress(:asset, entry, socket) do
    if entry.done? do
      consume_uploaded_entries(socket, :asset, fn %{path: path}, entry ->
        # TODO: pass site name
        MediaLibrary.upload(
          "my_site",
          path,
          entry.client_name,
          entry.client_type
        )

        {:ok, path}
      end)

      {:noreply,
       socket
       |> put_flash(:info, "Asset created successfully")
       |> push_navigate(to: socket.assigns.navigate)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  # def handle_event("save", %{"asset" => asset_params}, socket) do
  #   save_asset(socket, socket.assigns.action, asset_params)
  # end
end
