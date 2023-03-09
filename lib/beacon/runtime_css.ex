defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime compilation and processing of CSS files.
  """

  require Logger

  @callback compile!(Beacon.Type.Site.t()) :: String.t()

  @doc """
  Compiles the site CSS through tailwind-cli
  """
  @spec compile!(Beacon.Type.Site.t()) :: String.t()
  def compile!(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.compile!(site)
  end

  @doc false
  def fetch(site) do
    case :ets.match(:beacon_runtime_css, {site, :"$1"}) do
      [[css]] -> css
      _ -> "/* CSS not found for site #{inspect(site)} */"
    end
  end

  @doc false
  def load(site) do
    :ets.insert(:beacon_runtime_css, {site, compile!(site)})
  end
end
