defmodule Beacon.PubSub do
  require Logger

  @pubsub __MODULE__

  def subscribe_page_update(site, path) do
    subscribe("page_update:#{site}:#{path}")
  end

  def broadcast_page_update(site, path) do
    broadcast("page_update:#{site}:#{path}", :page_updated)
  end

  defp broadcast(channel, message) when is_binary(channel) do
    Logger.debug("broadcast #{inspect(channel)} #{inspect(message)}")
    Phoenix.PubSub.broadcast(@pubsub, channel, message)
  end

  # defp endpoint_broadcast(endpoint, topic, event, message) do
  #   endpoint.broadcast(topic, event, message)
  # end

  defp subscribe(channel) when is_binary(channel) do
    Logger.debug("subscribe #{inspect(channel)}")
    Phoenix.PubSub.subscribe(@pubsub, channel)
  end
end
