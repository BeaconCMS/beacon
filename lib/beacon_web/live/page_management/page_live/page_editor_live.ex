defmodule BeaconWeb.PageManagement.PageEditorLive do
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
      |> assign_layouts()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"page" => page_attrs, "publish" => publish}, socket) do
    {:ok, page} =
      Pages.update_page_pending(
        socket.assigns.page,
        page_attrs["pending_template"],
        page_attrs["pending_layout_id"]
      )

    if publish == "true" do
      {:ok, _page} = Pages.publish_page(page)
    end

    {:noreply, assign_page_and_changeset(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"page" => page}, socket) do
    page = %{"pending_template" => String.trim(page["pending_template"])}

    changeset =
      socket.assigns.page
      |> Pages.change_page(page)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_layouts()

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

  defp assign_layouts(%{assigns: %{changeset: changeset}} = socket) do
    layouts =
      changeset
      |> Ecto.Changeset.get_field(:site)
      |> Layouts.list_layouts_for_site()

    assign(socket, :site_layouts, layouts)
  end

  defp assign_page_and_changeset(socket) do
    page = Pages.get_page!(socket.assigns.page_id, [:versions])

    socket
    |> assign(:page, page)
    |> assign(:changeset, Pages.change_page(page))
  end

  defp layouts_to_options(layouts) do
    Enum.map(layouts, fn %Layout{id: id, title: title} ->
      {title, id}
    end)
  end

  defp sort_page_versions(page_versions) do
    Enum.sort(page_versions, &(&2.inserted_at <= &1.inserted_at))
  end
end
