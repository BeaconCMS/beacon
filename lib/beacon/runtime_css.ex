defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime compilation and processing of CSS files.
  """

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
    case :ets.match(:beacon_assets, {{site, :css}, {:_, :"$1"}}) do
      [[css]] -> css
      _ -> "/* CSS not found for site #{inspect(site)} */"
    end
  end

  @doc false
  def load(site) do
    css = compile!(site)
    hash = Base.encode16(:crypto.hash(:md5, css), case: :lower)
    :ets.insert(:beacon_assets, {{site, :css}, {hash, css}})
  end

  @doc false
  def load_admin do
    css =
      :beacon
      |> Application.app_dir(["priv", "static", "assets", "admin.css"])
      |> File.read!()

    hash = Base.encode16(:crypto.hash(:md5, css), case: :lower)
    :ets.insert(:beacon_assets, {{:beacon_admin, :css}, {hash, css}})
  end

  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :css}, {:"$1", :_}}) do
      [[hash]] -> hash
      _ -> ""
    end
  end
end
