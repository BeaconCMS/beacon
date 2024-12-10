defmodule Beacon.ProxyEndpoint do
  @moduledoc """
  TODO: moduledoc

      use Beacon.ProxyEndpoint, otp_app: :my_app, endpoints: [MyAppWeb.EndpointSiteA, MyAppWeb.EndpointSiteB]
  """

  @doc """
  TODO: doc
  """
  defmacro __using__(opts) do
    quote location: :keep, generated: true do
      otp_app = Keyword.get(unquote(opts), :otp_app) || raise Beacon.RuntimeError, "FIXME 1"

      proxy_options = Application.compile_env!(otp_app, __MODULE__) || raise Beacon.RuntimeError, "FIXME 2"

      session_options = proxy_options[:session] || raise Beacon.RuntimeError, "FIXME 3"
      Module.put_attribute(__MODULE__, :session_options, session_options)

      endpoints = Keyword.get(unquote(opts), :endpoints, [])
      Module.put_attribute(__MODULE__, :__beacon_proxy_endpoints__, endpoints)

      fallback = Keyword.get(unquote(opts), :fallback) || raise Beacon.RuntimeError, "FIXME 4"
      Module.put_attribute(__MODULE__, :__beacon_proxy_fallback__, fallback)

      use Phoenix.Endpoint, otp_app: otp_app

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [session: @session_options]],
        longpoll: [connect_info: [session: @session_options]]

      plug :proxy

      def proxy(conn, opts) do
        %{host: host} = conn
        endpoint = Enum.find(@__beacon_proxy_endpoints__, @__beacon_proxy_fallback__, &(&1.host() == host))
        endpoint.call(conn, endpoint.init(opts))
      end
    end
  end
end
