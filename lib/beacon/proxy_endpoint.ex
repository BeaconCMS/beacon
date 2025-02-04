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

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [session: @session_options]],
        longpoll: [connect_info: [session: @session_options]]

      plug :proxy

      # TODO: cache endpoint resolver
      def proxy(%{host: host} = conn, opts) do
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

  # TODO: docs, spec, error handling

  # https://github.com/phoenixframework/phoenix/blob/2614f2a0d95a3b4b745bdf88ccd9f3b7f6d5966a/lib/phoenix/endpoint/supervisor.ex#L386
  # proxy is the public facing entrypoint, ie: scheme and port
  # host is defined by the site endpoint, which is used to generate links
  def public_uri(site) do
    site_endpoint = Beacon.Config.fetch!(site).endpoint
    proxy_endpoint = site_endpoint.proxy_endpoint()

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

    if host =~ ~r"[^:]:\d" do
      Logger.warning("url: [host: ...] configuration value #{inspect(host)} for #{inspect(site_endpoint)} is invalid")
    end

    %URI{scheme: scheme, port: port, host: host}
  end

  @doc """
  TODO
  """
  def public_url(site) do
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
end
