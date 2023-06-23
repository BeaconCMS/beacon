defmodule BeaconWeb.Admin.MediaLibraryLive.ShowComponent do
  use BeaconWeb, :live_component

  alias Beacon.Admin.MediaLibrary

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header class="mb-8"><%= @asset.file_name %></.header>
      <img :if={@is_image?} src={@url} class="mb-8" />
      <ul>
        <%= for {url, index} <- @urls do %>
          <li class="flex mb-8">
            <input type="text" id={"url-#{index}"} value={url} class="input w-full border-neutral-200 bg-neutral-100 py-2 border-2 pr-8" />
            <div class="flex">
              <button phx-click={JS.dispatch("beacon_admin:clipcopy", to: "#url-#{index}")}>
                <.icon name="hero-clipboard-document-check-solid" class="h-5 w-5" />
              </button>
            </div>
            <div
              id={"url-#{index}-copy-to-clipboard-result"}
              class="absolute right-0 -top-10 whitespace-nowrap text-green-500 text-sm font-medium p-3 shadow-md rounded-lg bg-white transition-all duration-300 opacity-0 invisible"
              phx-update="ignore"
            >
              Copied to clipboard
            </div>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    asset = assigns.asset

    socket =
      socket
      |> assign(assigns)
      |> assign(:is_image?, MediaLibrary.is_image?(asset))
      |> assign(:url, MediaLibrary.url_for(asset))
      |> assign(:urls, urls_for(asset))

    {:ok, socket}
  end

  defp urls_for(asset) do
    asset
    |> MediaLibrary.urls_for()
    |> Enum.with_index()
  end
end
