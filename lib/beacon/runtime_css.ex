defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime compilation and processing of CSS files.
  """

  @callback compile(Beacon.Types.Site.t()) :: {:ok, String.t()} | {:error, any()}

  @doc """
  Compiles the site CSS through tailwind-cli
  """
  @spec compile(Beacon.Types.Site.t()) :: {:ok, String.t()} | {:error, any()}
  def compile(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.compile(site)
  end

  @doc false
  def fetch(site) do
    case :ets.match(:beacon_assets, {{site, :css}, {:_, :_, :"$1"}}) do
      [[css]] -> css
      _ -> "/* CSS not found for site #{inspect(site)} */"
    end
  end

  @doc false
  def load(site) do
    {:ok, css} = compile(site)
    compressed = :zlib.gzip(css)
    hash = Base.encode16(:crypto.hash(:md5, css), case: :lower)
    true = :ets.insert(:beacon_assets, {{site, :css}, {hash, css, compressed}})
    :ok
  end

  @doc false
  def load_admin do
    css =
      :beacon
      |> Application.app_dir(["priv", "static", "assets", "admin.css"])
      |> File.read!()

    compressed = :zlib.gzip(css)

    hash = Base.encode16(:crypto.hash(:md5, css), case: :lower)
    true = :ets.insert(:beacon_assets, {{:beacon_admin, :css}, {hash, css, compressed}})
    :ok
  end

  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :css}, {:"$1", :_, :_}}) do
      [[hash]] -> hash
      _ -> ""
    end
  end
end
