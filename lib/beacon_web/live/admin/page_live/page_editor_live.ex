defmodule BeaconWeb.Admin.PageEditorLive do
  use BeaconWeb, :live_view

  alias Beacon.Layouts
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    socket =
      socket
      |> assign(:page_id, id)
      |> assign_page_and_changeset()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"page" => page_params, "publish" => publish}, socket) do
    {:ok, page} =
      Pages.update_page_pending(
        socket.assigns.page,
        page_params["pending_template"],
        page_params["pending_layout_id"],
        page_params
      )

    if publish == "true" do
      {:ok, _page} = Pages.publish_page(page)
    end

    {:noreply, assign_page_and_changeset(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"page" => page_params}, socket) do
    changeset =
      socket.assigns.page
      |> Pages.change_page(page_params)
      |> Map.put(:action, :validate)

    socket = assign_changeset(socket, changeset)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("copy_version", %{"version" => version_str}, socket) do
    version = Enum.find(socket.assigns.page.versions, &(&1.version == String.to_integer(version_str)))

    Pages.update_page_pending(
      socket.assigns.page,
      version.template,
      socket.assigns.page.layout_id
    )

    {:noreply, assign_page_and_changeset(socket)}
  end

  defp assign_page_and_changeset(socket) do
    page = Pages.get_page!(socket.assigns.page_id, [:versions])

    socket
    |> assign(:page, page)
    |> assign_changeset(Pages.change_page(page))
  end

  defp layouts_to_options(layouts) do
    Enum.map(layouts, fn %Layout{id: id, title: title} ->
      {title, id}
    end)
  end

  defp sort_page_versions(page_versions) do
    Enum.sort_by(page_versions, & &1.version, :desc)
  end

  defp assign_changeset(socket, new_changeset) do
    # Only update the :site_layouts assign if the site has changed
    old_site =
      case socket.assigns[:changeset] do
        %Ecto.Changeset{} = changeset -> Ecto.Changeset.get_field(changeset, :site)
        _ -> nil
      end

    new_site = Ecto.Changeset.get_field(new_changeset, :site)

    if old_site != new_site do
      assign(socket, changeset: new_changeset, site_layouts: Layouts.list_layouts_for_site(new_site))
    else
      assign(socket, changeset: new_changeset)
    end
  end
end
