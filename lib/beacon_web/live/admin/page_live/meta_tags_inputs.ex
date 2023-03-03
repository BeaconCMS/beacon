defmodule BeaconWeb.Admin.PageLive.MetaTagsInputs do
  use BeaconWeb, :live_component

  alias Phoenix.HTML.Form

  @default_attributes ["name", "property", "content"]

  @impl true
  def mount(socket) do
    socket =
      assign(socket,
        attributes: @default_attributes,
        extra_attributes: [],
        meta_tags: []
      )

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> handle_changes()

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

  defp handle_changes(socket) do
    if changed?(socket, :field) or changed?(socket, :extra_attributes) do
      # Fetch the meta tags from the form field
      {form, field} = socket.assigns.field
      meta_tags = Form.input_value(form, field)

      # Aggregate all known meta tag attributes
      attributes = Enum.uniq(socket.assigns.attributes ++ Enum.flat_map(meta_tags, &Map.keys/1) ++ socket.assigns.extra_attributes)

      assign(socket, meta_tags: meta_tags, attributes: attributes)
    else
      socket
    end
  end

  defp input_name({form, field}, index, attribute) do
    Form.input_name(form, field) <> "[#{index}][#{attribute}]"
  end

  defp input_id({form, field}, index, attribute) do
    Form.input_id(form, field) <> "_#{index}_#{attribute}"
  end

  # Convert params map %{"0" => %{...}, "1" => %{...}} into a list of maps
  def coerce_meta_tag_param(params, field) do
    case Map.fetch(params, field) do
      {:ok, map} -> Map.put(params, field, Map.values(map))
      :error -> params
    end
  end
end
