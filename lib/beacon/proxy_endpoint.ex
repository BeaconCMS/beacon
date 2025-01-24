defmodule Beacon.ProxyEndpoint do
  @moduledoc false

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

      def proxy(conn, opts) do
        %{host: host} = conn

        # TODO: cache endpoint resolver
        endpoint =
          Enum.reduce_while(Beacon.Registry.running_sites(), @__beacon_proxy_fallback__, fn site, default ->
            %{endpoint: endpoint} = Beacon.Config.fetch!(site)

            if endpoint.host() == host do
              {:halt, endpoint}
            else
              {:cont, default}
            end
          end)

        endpoint.call(conn, endpoint.init(opts))
      end

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
end
