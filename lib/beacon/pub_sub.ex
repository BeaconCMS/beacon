defmodule Beacon.PubSub do
  @moduledoc false

  require Logger
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.PageEvent

  @pubsub __MODULE__

  @topic_layout_published "beacon:layout:published"
  @topic_page_published "beacon:page:published"

  def subscribe_layout_published do
    Phoenix.PubSub.subscribe(@pubsub, @topic_layout_published)
  end

  def broadcast_layout_published(%LayoutEvent{} = event) do
    broadcast(@topic_layout_published, event)
  end

  def subscribe_page_published do
    Phoenix.PubSub.subscribe(@pubsub, @topic_page_published)
  end

  def broadcast_page_published(%PageEvent{} = event) do
    broadcast(@topic_page_published, event)
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
