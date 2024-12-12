defmodule Beacon.ProxyEndpoint do
  @moduledoc """
  Proxy Endpoint to redirect requests to each site endpoint in a multiple domains setup.

      TODO: beacon.deploy.add_domain fobar

      TODO: use Beacon.ProxyEndpoint, otp_app: :my_app, endpoints: [MyAppWeb.EndpointSiteA, MyAppWeb.EndpointSiteB]

  """

  @doc """
  TODO: doc
  """
  defmacro __using__(opts) do
    quote location: :keep, generated: true do
      otp_app = Keyword.get(unquote(opts), :otp_app) || raise Beacon.RuntimeError, "FIXME missing otp_app"

      session_options = Keyword.get(unquote(opts), :session_options) || raise Beacon.RuntimeError, "FIXME missing session_options"
      Module.put_attribute(__MODULE__, :session_options, session_options)

      fallback = Keyword.get(unquote(opts), :fallback) || raise Beacon.RuntimeError, "FIXME missing fallback"
      Module.put_attribute(__MODULE__, :__beacon_proxy_fallback__, fallback)

      use Phoenix.Endpoint, otp_app: otp_app

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [session: @session_options]],
        longpoll: [connect_info: [session: @session_options]]

      plug :proxy

      def proxy(conn, opts) do
        %{host: host} = conn

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
    end
  end
end
