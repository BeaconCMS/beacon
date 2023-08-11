defmodule Beacon.PubSub do
  @moduledoc false

  require Logger
  alias Beacon.Content.Component
  alias Beacon.Content.Layout
  alias Beacon.Content.Page

  @pubsub __MODULE__

  # Layouts

  defp topic_layouts(site), do: "beacon:#{site}:layouts"

  def subscribe_to_layouts(site) do
    Phoenix.PubSub.subscribe(@pubsub, topic_layouts(site))
  end

  def layout_published(%Layout{} = layout) do
    layout.site
    |> topic_layouts()
    |> broadcast({:layout_published, %{site: layout.site, id: layout.id}})
  end

  # Pages

  defp topic_pages(site), do: "beacon:#{site}:pages"

  defp topic_page(site, path) when is_list(path) do
    path = Enum.join(path, "/")
    topic_page(site, path)
  end

  defp topic_page(site, path) when is_binary(path) do
    "beacon:#{site}:pages:#{path}"
  end

  def subscribe_to_pages(site) do
    Phoenix.PubSub.subscribe(@pubsub, topic_pages(site))
  end

  def subscribe_to_page(site, path) do
    Phoenix.PubSub.subscribe(@pubsub, topic_page(site, path))
  end

  def page_created(%Page{} = page) do
    page.site
    |> topic_pages()
    |> broadcast({:page_created, page(page)})
  end

  def page_loaded(%Page{} = page) do
    page.site
    |> topic_page(page.path)
    |> local_broadcast({:page_loaded, page(page)})
  end

  def page_published(%Page{} = page) do
    page.site
    |> topic_pages()
    |> broadcast({:page_published, page(page)})
  end

  def pages_published(pages) when is_list(pages) do
    messages =
      pages
      |> Enum.group_by(& &1.site)
      |> Enum.map(fn {site, pages} ->
        pages = Enum.map(pages, &page/1)

        site
        |> topic_pages()
        |> broadcast({:pages_published, site, pages})
      end)

    if Enum.all?(messages, &(&1 == :ok)), do: :ok, else: :error
  end

  def page_unpublished(%Page{} = page) do
    page.site
    |> topic_pages()
    |> broadcast({:page_unpublished, page(page)})
  end

  defp page(page), do: %{site: page.site, id: page.id, path: page.path}

  # Components

  defp topic_components(site), do: "beacon:#{site}:components"

  defp topic_component(site, id) when is_binary(id) do
    "beacon:#{site}:components:#{id}"
  end

  def subscribe_to_components(site) do
    Phoenix.PubSub.subscribe(@pubsub, topic_components(site))
  end

  def subscribe_to_component(site, id) do
    Phoenix.PubSub.subscribe(@pubsub, topic_component(site, id))
  end

  def component_updated(%Component{} = component) do
    component.site
    |> topic_components()
    |> broadcast({:component_updated, component(component)})
  end

  def component_loaded(component) do
    component.site
    |> topic_component(component.id)
    |> local_broadcast({:component_loaded, component(component)})
  end

  defp component(component), do: %{site: component.site, id: component.id, name: component.name}

  # Utils

  defp broadcast(topic, message) when is_binary(topic) do
    Phoenix.PubSub.broadcast(@pubsub, topic, message)
  end

  defp local_broadcast(topic, message) when is_binary(topic) do
    Phoenix.PubSub.local_broadcast(@pubsub, topic, message)
  end
end
