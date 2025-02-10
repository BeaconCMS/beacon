defmodule Beacon.ProxyEndpoint do
  @moduledoc false

  require Logger

  defmacro __using__(opts) do
    quote location: :keep, generated: true do
      otp_app = Keyword.get(unquote(opts), :otp_app) || raise Beacon.RuntimeError, "missing required option :otp_app in Beacon.ProxyEndpoint"

      session_options =
        Keyword.get(unquote(opts), :session_options) || raise Beacon.RuntimeError, "missing required option :session_options in Beacon.ProxyEndpoint"

      Module.put_attribute(__MODULE__, :session_options, session_options)

      fallback = Keyword.get(unquote(opts), :fallback) || raise Beacon.RuntimeError, "missing required option :fallback in Beacon.ProxyEndpoint"
      Module.put_attribute(__MODULE__, :__beacon_proxy_fallback__, fallback)

      use Phoenix.Endpoint, otp_app: otp_app
      import Plug.Conn, only: [put_resp_content_type: 2, put_resp_header: 3, halt: 1]
      import Phoenix.Controller, only: [accepts: 2, put_view: 2, render: 3]

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [session: @session_options]],
        longpoll: [connect_info: [session: @session_options]]

      plug :robots
      plug :sitemap_index
      plug :proxy

      defp robots(%{path_info: ["robots.txt"]} = conn, _opts) do
        sitemap_index_url = Beacon.ProxyEndpoint.public_url(__MODULE__, conn.host) <> "/sitemap_index.xml"

        conn
        |> accepts(["txt"])
        |> put_view(Beacon.Web.RobotsTxt)
        |> put_resp_content_type("text/txt")
        |> put_resp_header("cache-control", "public max-age=300")
        |> render(:robots, sitemap_index_url: sitemap_index_url)
        |> halt()
      end

      defp robots(conn, _opts), do: conn

      defp sitemap_index(%{path_info: ["sitemap_index.xml"]} = conn, _opts) do
        sites = Beacon.ProxyEndpoint.sites_per_host(conn.host)

        conn
        |> accepts(["xml"])
        |> put_view(Beacon.Web.SitemapXML)
        |> put_resp_content_type("text/xml")
        |> put_resp_header("cache-control", "public max-age=300")
        |> render(:sitemap_index, urls: get_sitemap_urls(sites))
        |> halt()
      end

      defp sitemap_index(conn, _opts), do: conn

      defp get_sitemap_urls(sites) do
        sites
        |> Enum.map(fn site ->
          routes_module = Beacon.Loader.fetch_routes_module(site)
          Beacon.apply_mfa(site, routes_module, :public_sitemap_url, [])
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort()
        |> Enum.uniq()
      end

      # TODO: cache endpoint resolver
      defp proxy(%{host: host} = conn, opts) do
        matching_endpoint = fn ->
          Enum.reduce_while(Beacon.Registry.running_sites(), @__beacon_proxy_fallback__, fn site, default ->
            %{endpoint: endpoint} = Beacon.Config.fetch!(site)

            if endpoint.host() == host do
              {:halt, endpoint}
            else
              {:cont, default}
            end
          end)
        end

        # fallback endpoint has higher priority in case of conflicts,
        # for eg when all endpoints' host are localhost
        endpoint =
          if @__beacon_proxy_fallback__.host() == host do
            @__beacon_proxy_fallback__
          else
            matching_endpoint.()
          end

        endpoint.call(conn, endpoint.init(opts))
      end

      @doc """
      Check origin dynamically.

      Used in the ProxyEndpoint `:check_origin` config to check the origin request
      against the fallback endpoint and all running site's endpoints.

      It checks if the requested scheme://host is the same as any of the available endpoints.

      It doesn't check the scheme if not available, so in some cases it might check only the host.
      Port is never checked since the proxied (children) endpoints don't use the same port as
      as the requested URI.
      """
      def check_origin(%URI{} = uri) do
        check_origin_fallback_endpoint = fn ->
          url = @__beacon_proxy_fallback__.config(:url)
          check_origin(uri, url[:scheme], url[:host])
        end

        Enum.any?(Beacon.Registry.running_sites(), fn site ->
          url = Beacon.Config.fetch!(site).endpoint.config(:url)
          check_origin(uri, url[:scheme], url[:host])
        end) || check_origin_fallback_endpoint.()
      end

      def check_origin(_), do: false

      defp check_origin(%{scheme: scheme, host: host}, scheme, host) when is_binary(scheme) and is_binary(host), do: true
      defp check_origin(%{host: host}, nil, host) when is_binary(host), do: true
      defp check_origin(_, _), do: false
    end
  end

  @doc false
  def public_uri(endpoint, host) do
    url = endpoint.config(:url)
    https = endpoint.config(:https)
    http = endpoint.config(:http)

    {scheme, port} =
      cond do
        https -> {"https", https[:port] || 443}
        http -> {"http", http[:port] || 80}
        true -> {"http", 80}
      end

    scheme = url[:scheme] || scheme
    host = host_to_binary(host || "localhost")
    port = port_to_integer(url[:port] || port)

    %URI{scheme: scheme, host: host, port: port}
  end

  def public_url(endpoint, host) do
    endpoint
    |> public_uri(host)
    |> String.Chars.URI.to_string()
  end

  # https://github.com/phoenixframework/phoenix/blob/2614f2a0d95a3b4b745bdf88ccd9f3b7f6d5966a/lib/phoenix/endpoint/supervisor.ex#L386
  @doc """
  Similar to `public_url/1` but returns a `%URI{}` instead.
  """
  @spec public_uri(Beacon.Types.Site.t()) :: URI.t()
  def public_uri(site) when is_atom(site) do
    site_endpoint = Beacon.Config.fetch!(site).endpoint
    proxy_endpoint = site_endpoint.proxy_endpoint()
    router = Beacon.Config.fetch!(site).router

    proxy_url = proxy_endpoint.config(:url)
    site_url = site_endpoint.config(:url)

    https = proxy_endpoint.config(:https)
    http = proxy_endpoint.config(:http)

    {scheme, port} =
      cond do
        https -> {"https", https[:port] || 443}
        http -> {"http", http[:port] || 80}
        true -> {"http", 80}
      end

    scheme = proxy_url[:scheme] || scheme
    host = host_to_binary(site_url[:host] || "localhost")
    port = port_to_integer(proxy_url[:port] || port)
    path = router.__beacon_scoped_prefix_for_site__(site)

    if host =~ ~r"[^:]:\d" do
      Logger.warning("url: [host: ...] configuration value #{inspect(host)} for #{inspect(site_endpoint)} is invalid")
    end

    %URI{scheme: scheme, host: host, port: port, path: path}
  end

  @doc """
  Returns the public URL of a given `site`.

  Scheme and port are fetched from the Proxy Endpoint to resolve the URL correctly
  """
  @spec public_url(Beacon.Types.Site.t()) :: String.t()
  def public_url(site) when is_atom(site) do
    site
    |> public_uri()
    |> String.Chars.URI.to_string()
  end

  # TODO: Remove the first function clause once {:system, env_var} tuples are removed
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host

  # TODO: Remove the first function clause once {:system, env_var} tuples are removed
  defp port_to_integer({:system, env_var}), do: port_to_integer(System.get_env(env_var))
  defp port_to_integer(port) when is_binary(port), do: String.to_integer(port)
  defp port_to_integer(port) when is_integer(port), do: port

  @doc false
  def sites_per_host(host) when is_binary(host) do
    Enum.reduce(Beacon.Registry.running_sites(), [], fn site, acc ->
      %{endpoint: endpoint} = Beacon.Config.fetch!(site)

      if endpoint.host() == host do
        [site | acc]
      else
        acc
      end
    end)
  end
end
