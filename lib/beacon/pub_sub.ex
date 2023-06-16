defmodule Beacon.PubSub do
  @moduledoc false

  require Logger
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.PageEvent

  @pubsub __MODULE__

  @topic_layouts "beacon:layouts"
  @topic_pages "beacon:pages"

  def subscribe_layouts do
    Phoenix.PubSub.subscribe(@pubsub, @topic_layouts)
  end

  def broadcast_layout_event(%LayoutEvent{} = event) do
    broadcast(@topic_layouts, event)
  end

  def subscribe_pages do
    Phoenix.PubSub.subscribe(@pubsub, @topic_pages)
  end

  def broadcast_page_event(%PageEvent{} = event) do
    broadcast(@topic_pages, event)
  end

  def subscribe_page_update(site, path_info) do
    path = Enum.join(path_info, "/")
    subscribe("beacon:page_update:#{site}:#{path}")
  end

  def broadcast_page_update(site, path) do
    broadcast("beacon:page_update:#{site}:#{path}", :page_updated)
  end

  def broadcast_page_published(site, page_id) when is_atom(site) and is_binary(page_id) do
    broadcast("beacon:page_published", %{site: site, page_id: page_id})
  end

  defp broadcast(channel, message) when is_binary(channel) do
    Phoenix.PubSub.broadcast(@pubsub, channel, message)
  end

  defp subscribe(channel) when is_binary(channel) do
    Phoenix.PubSub.subscribe(@pubsub, channel)
  end
end
