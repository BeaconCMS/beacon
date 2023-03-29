defmodule BeaconWeb.Admin.MediaLibraryLive.UploadFormComponent do
  use BeaconWeb, :live_component

  alias Beacon.Admin.MediaLibrary
  alias Beacon.Admin.MediaLibrary.Asset
  alias Beacon.Authorization

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>Upload</.header>

      <section phx-drop-target={@uploads.asset.ref}>
        <%= for entry <- @uploads.asset.entries do %>
          <article class="upload-entry">
            <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>
          </article>
        <% end %>
      </section>

      <%= if Authorization.authorized?(@agent, :upload, %Asset{}) do %>
        <.form for={%{}} as={:assets} id="asset-form" phx-target={@myself} phx-change="validate" phx-submit="save">
          <.live_file_input upload={@uploads.asset} tabindex="0" />
        </.form>
      <% end %>

      <%= for entry <- @uploads.asset.entries do %>
        <%= for err <- upload_errors(@uploads.asset, entry) do %>
          <p class="text-red-600">
            <%= entry.client_name %>
            <%= Phoenix.Naming.humanize(err) %>
          </p>
        <% end %>
      <% end %>

      <div :if={@uploaded_assets != []}>
        <%= for asset <- @uploaded_assets do %>
          <p class="text-green-600"><%= asset.file_name %></p>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:uploaded_assets, [])
     |> allow_upload(:asset,
       auto_upload: true,
       progress: &handle_progress/3,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 10
     )}
  end

  defp handle_progress(:asset, entry, socket) do
    uploaded_assets =
      consume_uploaded_entries(socket, :asset, fn %{path: path}, _entry ->
        MediaLibrary.upload(
          "dev",
          path,
          entry.client_name,
          entry.client_type
        )
      end)

    {:noreply, update(socket, :uploaded_assets, &(&1 ++ uploaded_assets))}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end
end
