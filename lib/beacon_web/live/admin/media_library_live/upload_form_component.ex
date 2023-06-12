defmodule BeaconWeb.Admin.MediaLibraryLive.UploadFormComponent do
  use BeaconWeb, :live_component

  alias Beacon.Admin.MediaLibrary
  alias Beacon.Admin.MediaLibrary.UploadMetadata
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

      <.form
        :if={Authorization.authorized?(@agent, :upload, %{mod: :media_library})}
        for={%{"site" => @site_selected}}
        as={:assets}
        id="asset-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          id="site-input"
          name="site"
          type="select"
          label="Site"
          options={@sites}
          value={@site_selected}
          phx-change="set_site"
          phx-target={@myself}
        />
        <.live_file_input upload={@uploads.asset} tabindex="0" />
      </.form>

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
    sites = Beacon.Registry.registered_sites()
    site_selected = hd(sites)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:uploaded_assets, [])
     |> assign(:sites, sites)
     |> assign(:site_selected, site_selected)
     |> allow_upload(:asset,
       auto_upload: true,
       progress: &handle_progress/3,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 10
     )}
  end

  defp handle_progress(:asset, entry, socket) do
    site =
      case socket.assigns.site_selected do
        site when is_binary(site) -> String.to_existing_atom(site)
        site -> site
      end

    uploaded_assets =
      consume_uploaded_entries(socket, :asset, fn %{path: path}, _entry ->
        asset =
          site
          |> UploadMetadata.new(path, name: entry.client_name, media_type: entry.client_type, size: entry.client_size)
          |> MediaLibrary.upload()

        {:ok, asset}
      end)

    {:noreply, update(socket, :uploaded_assets, &(&1 ++ uploaded_assets))}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_site", %{"site" => site}, socket) when is_binary(site) do
    {:noreply, assign(socket, :site_selected, site)}
  end
end
