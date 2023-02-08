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

  """

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
  Return all the configuration for a given `site`.
  """
  def config_for_site!(site) when is_atom(site) do
    Kernel.get_in(Application.get_env(otp_app!(), Beacon), [:sites, site]) ||
      raise ArgumentError, """
      Could not find configuration for site #{inspect(site)}

      Make sure to define it at your config file:

          config :MY_APP, Beacon,
            sites: [
              #{site}: [
                data_source: MYAPP.BeaconDataSource
              ]
            ]

      See Beacon.Config for more info.
      """
  end

  @doc """

  """
  @spec data_source(atom() | String.t()) :: module() | nil
  def data_source(site) when is_binary(site), do: site |> String.to_atom() |> data_source()

  def data_source(site) when is_atom(site) do
    config_for_site!(site)[:data_source]
  end
end
