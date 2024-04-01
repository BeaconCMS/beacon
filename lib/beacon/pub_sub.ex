defmodule Beacon.PubSub do
  @moduledoc false

  alias Beacon.Content

  @pubsub __MODULE__

  # Content

  defp topic_content(site), do: "beacon:#{site}:content"

  def subscribe_to_content(site) do
    Phoenix.PubSub.subscribe(@pubsub, topic_content(site))
  end

  def content_updated(site, resource_type) do
    site
    |> topic_content()
    |> broadcast({:content_updated, resource_type, %{site: site}}, site)
  end

  # Layouts

  defp topic_layouts(site), do: "beacon:#{site}:layouts"

  def subscribe_to_layouts(site) do
    Phoenix.PubSub.subscribe(@pubsub, topic_layouts(site))
  end

  def layout_published(%Content.Layout{} = layout) do
    layout.site
    |> topic_layouts()
    |> broadcast({:layout_published, layout(layout)}, layout.site)
  end

  defp layout(layout), do: %{site: layout.site, id: layout.id}

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

  def page_loaded(%Content.Page{} = page) do
    page.site
    |> topic_page(page.path)
    |> local_broadcast({:page_loaded, page(page)}, page.site)
  end

  def page_published(%Content.Page{} = page) do
    page.site
    |> topic_pages()
    |> broadcast({:page_published, page(page)}, page.site)
  end

  def pages_published(pages) when is_list(pages) do
    messages =
      pages
      |> Enum.group_by(& &1.site)
      |> Enum.map(fn {site, pages} ->
        pages = Enum.map(pages, &page/1)

        site
        |> topic_pages()
        |> broadcast({:pages_published, site, pages}, site)
      end)

    if Enum.all?(messages, &(&1 == :ok)), do: :ok, else: :error
  end

  def page_unpublished(%Content.Page{} = page) do
    page.site
    |> topic_pages()
    |> broadcast({:page_unpublished, page(page)}, page.site)
  end

  defp page(page), do: %{site: page.site, id: page.id, path: page.path}

  # Utils

  defp broadcast(topic, message, site) when is_binary(topic) do
    if Beacon.Config.fetch!(site).skip_boot? do
      :ok
    else
      Phoenix.PubSub.broadcast(@pubsub, topic, message)
    end
  end

  defp local_broadcast(topic, message, site) when is_binary(topic) do
    if Beacon.Config.fetch!(site).skip_boot? do
      :ok
    else
      Phoenix.PubSub.local_broadcast(@pubsub, topic, message)
    end
  end
end
