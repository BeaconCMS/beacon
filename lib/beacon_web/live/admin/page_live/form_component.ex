defmodule BeaconWeb.Admin.PageLive.FormComponent do
  use BeaconWeb, :live_component

  alias Beacon.Layouts
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  @impl true
  def update(%{page: page} = assigns, socket) do
    changeset = Pages.change_page(page)

    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset)
      |> assign_layouts()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"page" => page_params}, socket) do
    changeset =
      socket.assigns.page
      |> Pages.change_page(page_params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign_layouts()

    {:noreply, socket}
  end

  def handle_event("save", %{"page" => page_params}, socket) do
    save_page(socket, socket.assigns.action, page_params)
  end

  # defp save_page(socket, :edit, page_params) do
  #   case Pages.update_page(socket.assigns.page, page_params) do
  #     {:ok, _page} ->
  #       {:noreply,
  #        socket
  #        |> put_flash(:info, "Page updated successfully")
  #        |> push_redirect(to: socket.assigns.return_to)}

  #     {:error, %Ecto.Changeset{} = changeset} ->
  #       {:noreply, assign(socket, :changeset, changeset)}
  #   end
  # end

  defp save_page(socket, :new, page_params) do
    case Pages.create_page(page_params) do
      {:ok, _page} ->
        {:noreply,
         socket
         |> put_flash(:info, "Page created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:changeset, changeset)
          |> assign(:errors, changeset.errors)

        {:noreply, socket}
    end
  end

  defp assign_layouts(%{assigns: %{changeset: changeset}} = socket) do
    layouts =
      changeset
      |> Ecto.Changeset.get_field(:site)
      |> Layouts.list_layouts_for_site()

    assign(socket, :site_layouts, layouts)
  end

  defp layouts_to_options(layouts) do
    Enum.map(layouts, fn %Layout{id: id, title: title} ->
      {title, id}
    end)
  end
end
