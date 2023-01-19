defmodule BeaconWeb.Admin.PageLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Pages
  alias Beacon.Pages.Page

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:pages, list_pages())
      |> assign(:last_reload_time, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("reload_pages", _, socket) do
    start = :os.system_time(:millisecond)
    Beacon.Loader.reload_pages_from_db()

    {:noreply, assign(socket, :last_reload_time, :os.system_time(:millisecond) - start)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    page = Pages.get_page!(id)
    {:ok, _} = Pages.delete_page(page)

    {:noreply, assign(socket, :pages, list_pages())}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Page")
    |> assign(:page, Pages.get_page!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Page")
    |> assign(:page, %Page{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Pages")
    |> assign(:page, nil)
  end

  defp list_pages do
    Pages.list_pages()
  end
end
