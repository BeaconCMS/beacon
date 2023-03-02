defmodule BeaconWeb.Admin.PageLive.MetaTagsComponent do
  use BeaconWeb, :live_component

  @default_attributes ["name", "property", "content"]

  @impl true
  def mount(socket) do
    socket = assign(socket, attributes: @default_attributes, meta_tags: [])

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> handle_field_changed()

    {:ok, socket}
  end

  @impl true
  def handle_event("add", _, socket) do
    meta_tags = [%{} | socket.assigns.meta_tags]
    {:noreply, assign(socket, :meta_tags, meta_tags)}
  end

  @impl true
  def handle_event("delete", %{"index" => index}, socket) do
    meta_tags =
      case Integer.parse(index) do
        {index, _} -> List.delete_at(socket.assigns.meta_tags, index)
        :error -> socket.assigns.meta_tags
      end

    {:noreply, assign(socket, :meta_tags, meta_tags)}
  end

  defp handle_field_changed(socket) do
    if changed?(socket, :field) do
      {form, field} = socket.assigns.field
      meta_tags = Phoenix.HTML.Form.input_value(form, field)
      attributes = Enum.uniq(socket.assigns.attributes ++ Enum.flat_map(meta_tags, &Map.keys/1))

      assign(socket, meta_tags: meta_tags, attributes: attributes)
    else
      socket
    end
  end

  defp input_form({form, _field}), do: form
  defp input_field({_form, field}), do: field

  defp input_name(field, index, attribute) do
    Phoenix.HTML.Form.input_name(input_form(field), input_field(field)) <> "[#{index}][#{attribute}]"
  end

  defp input_id(field, index, attribute) do
    Phoenix.HTML.Form.input_id(input_form(field), input_field(field)) <> "_#{index}_#{attribute}"
  end

  # Convert params map %{"0" => %{...}, "1" => %{...}} into a list of maps
  def coerce_meta_tag_param(params, field) do
    case Map.fetch(params, field) do
      {:ok, map} -> Map.put(params, field, Map.values(map))
      :error -> params
    end
  end
end
