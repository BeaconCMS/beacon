defmodule Beacon.SEO.IndexNow do
  @moduledoc """
  Notifies search engines of page changes via the IndexNow protocol.

  IndexNow is supported by Bing, Yandex, Naver, and Seznam. When enabled,
  Beacon will notify these search engines immediately when a page is
  published or unpublished, instead of waiting for the next crawl.

  ## Configuration

      config :beacon, :sites, [
        [
          site: :my_site,
          index_now_key: "your-api-key",
          index_now_enabled: true,
          ...
        ]
      ]

  The key must also be served at `/{key}.txt` — Beacon handles this
  automatically via the ProxyEndpoint.
  """

  require Logger

  @index_now_url "https://api.indexnow.org/indexnow"

  @doc """
  Notifies IndexNow of a single URL change.

  Called automatically via the `after_publish_page` lifecycle hook
  when `index_now_enabled` is true.
  """
  @spec notify(Beacon.Types.Site.t(), String.t()) :: :ok | {:error, term()}
  def notify(site, page_url) when is_atom(site) and is_binary(page_url) do
    config = Beacon.Config.fetch!(site)

    unless config.index_now_enabled do
      :ok
    else
      key = config.index_now_key

      unless key do
        Logger.warning("[Beacon.SEO.IndexNow] index_now_enabled is true but index_now_key is not set for site #{site}")
        {:error, :no_key}
      else
        host = URI.parse(page_url).host || URI.parse(Beacon.RuntimeRenderer.public_site_url(site)).host
        do_notify(page_url, key, host)
      end
    end
  end

  @doc """
  Notifies IndexNow of multiple URL changes in a batch.
  """
  @spec notify_batch(Beacon.Types.Site.t(), [String.t()]) :: :ok | {:error, term()}
  def notify_batch(site, page_urls) when is_atom(site) and is_list(page_urls) do
    config = Beacon.Config.fetch!(site)

    unless config.index_now_enabled do
      :ok
    else
      key = config.index_now_key

      unless key do
        Logger.warning("[Beacon.SEO.IndexNow] index_now_enabled is true but index_now_key is not set for site #{site}")
        {:error, :no_key}
      else
        host = URI.parse(Beacon.RuntimeRenderer.public_site_url(site)).host
        do_notify_batch(page_urls, key, host)
      end
    end
  end

  @doc """
  Lifecycle hook function for `after_publish_page`.

  Add to your Beacon config:

      lifecycle: [
        after_publish_page: [&Beacon.SEO.IndexNow.on_publish/1]
      ]
  """
  @spec on_publish(map()) :: :ok
  def on_publish(%{site: site, path: path}) do
    page_url = Beacon.RuntimeRenderer.public_page_url(site, %{path: path})

    Task.start(fn ->
      case notify(site, page_url) do
        :ok -> :ok
        {:error, reason} ->
          Logger.warning("[Beacon.SEO.IndexNow] Failed to notify for #{page_url}: #{inspect(reason)}")
      end
    end)

    :ok
  end

  def on_publish(_), do: :ok

  # -- Private --

  defp do_notify(url, key, _host) do
    query = URI.encode_query(%{url: url, key: key})
    request_url = "#{@index_now_url}?#{query}"

    Logger.info("[Beacon.SEO.IndexNow] Notifying #{request_url}")

    case http_get(request_url) do
      {:ok, status} when status in 200..299 ->
        Logger.info("[Beacon.SEO.IndexNow] Successfully notified for #{url}")
        :ok

      {:ok, status} ->
        Logger.warning("[Beacon.SEO.IndexNow] Received status #{status} for #{url}")
        {:error, {:http_status, status}}

      {:error, reason} ->
        Logger.warning("[Beacon.SEO.IndexNow] HTTP error for #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_notify_batch(urls, key, host) do
    body = Jason.encode!(%{
      host: host,
      key: key,
      keyLocation: "https://#{host}/#{key}.txt",
      urlList: urls
    })

    Logger.info("[Beacon.SEO.IndexNow] Batch notifying #{length(urls)} URLs")

    case http_post(@index_now_url, body) do
      {:ok, status} when status in 200..299 ->
        Logger.info("[Beacon.SEO.IndexNow] Successfully batch notified #{length(urls)} URLs")
        :ok

      {:ok, status} ->
        Logger.warning("[Beacon.SEO.IndexNow] Batch received status #{status}")
        {:error, {:http_status, status}}

      {:error, reason} ->
        Logger.warning("[Beacon.SEO.IndexNow] Batch HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Simple HTTP client using :httpc (stdlib, no extra deps)
  defp http_get(url) do
    :httpc.request(:get, {String.to_charlist(url), []}, [timeout: 10_000], [])
    |> handle_httpc_response()
  end

  defp http_post(url, body) do
    headers = [{'content-type', 'application/json; charset=utf-8'}]
    :httpc.request(:post, {String.to_charlist(url), headers, 'application/json', String.to_charlist(body)}, [timeout: 10_000], [])
    |> handle_httpc_response()
  end

  defp handle_httpc_response({:ok, {{_, status, _}, _headers, _body}}), do: {:ok, status}
  defp handle_httpc_response({:error, reason}), do: {:error, reason}
end
