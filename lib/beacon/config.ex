defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  ## Examples

      config :beacon, otp_app: :my_app

      config :my_app, Beacon,
        sites: [
          dev: [data_source: BeaconDataSource]
        ]

  Each site my have the following options:

    * `:data_source` (optional) - module that implements `Beacon.DataSource` to provide assigns to pages.

    * `:live_socket_path` (optional) - path to live view socket, defaults to `/live`.

  """

  @defaults [
    data_source: nil,
    live_socket_path: "/live"
  ]

  @doc """
  Return the current OTP App.
  """
  def otp_app! do
    Application.get_env(:beacon, :otp_app) ||
      raise ArgumentError, """
      Could not find the otp_app configuration for your application.

      Make sure to define it at your config file:

          config :beacon, otp_app: :MY_APP

      See Beacon.Config for more info.
      """
  end

  @doc """
  Resolves and return all the configuration for a given `site`.

  Default values are returned if not present.

  ## Examples

      iex> config_for_site!(:blog)
      [{:data_source, MyApp.BeaconDataSource}, {:live_socket_path, "/live"}]

  """
  def config_for_site!(site) when is_atom(site) do
    old = Kernel.get_in(Application.get_env(otp_app!(), Beacon), [:sites, site]) || []
    Keyword.merge(@defaults, old)
  end

  @doc """
  TODO
  """
  @spec data_source(atom() | String.t()) :: module() | nil
  def data_source(site) when is_binary(site), do: site |> String.to_atom() |> data_source()

  def data_source(site) when is_atom(site) do
    config_for_site!(site)[:data_source]
  end

  @doc """
  TODO
  """
  @spec live_socket_path(atom() | String.t()) :: String.t()
  def live_socket_path(site) when is_binary(site), do: site |> String.to_atom() |> live_socket_path()

  def live_socket_path(site) when is_atom(site) do
    config_for_site!(site)[:live_socket_path]
  end
end
