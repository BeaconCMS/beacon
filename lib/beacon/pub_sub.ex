defmodule Beacon.PubSub do
  @moduledoc false

  require Logger

  @pubsub __MODULE__

  def subscribe_page_update(site, path_info) do
    path = Enum.join(path_info, "/")
    subscribe("beacon:page_update:#{site}:#{path}")
  end

  def broadcast_page_update(site, path) do
    broadcast("beacon:page_update:#{site}:#{path}", :page_updated)
  end

  defp broadcast(channel, message) when is_binary(channel) do
    Phoenix.PubSub.broadcast(@pubsub, channel, message)
  end

  defp subscribe(channel) when is_binary(channel) do
    Phoenix.PubSub.subscribe(@pubsub, channel)
  end
end
