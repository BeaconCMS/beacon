defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime compilation and processing of CSS files.
  """

  @callback compile(Beacon.Types.Site.t()) :: {:ok, String.t()} | {:error, any()}
  @callback compile(Beacon.Types.Site.t(), template :: String.t()) :: {:ok, String.t()} | {:error, any()}
  @callback compile(Beacon.Types.Site.t(), templates :: [String.t()]) :: {:ok, String.t()} | {:error, any()}

  @doc false
  def compile(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.compile(site)
  end

  @doc false
  def compile(site, template) when is_atom(site) and is_binary(template) do
    Beacon.Config.fetch!(site).css_compiler.compile(site, template)
  end

  @doc false
  def compile(site, templates) when is_atom(site) and is_list(templates) do
    Beacon.Config.fetch!(site).css_compiler.compile(site, templates)
  end

  @doc false
  def fetch(site, version \\ :compressed)

  def fetch(site, :compressed) do
    case :ets.match(:beacon_assets, {{site, :css}, {:_, :_, :"$1"}}) do
      [[css]] -> css
      _ -> "/* CSS not found for site #{inspect(site)} */"
    end
  end

  def fetch(site, :uncompressed) do
    case :ets.match(:beacon_assets, {{site, :css}, {:_, :"$1", :_}}) do
      [[css]] -> css
      _ -> "/* CSS not found for site #{inspect(site)} */"
    end
  end

  @doc false
  def load!(site) do
    {:ok, css} = compile(site)

    case ExBrotli.compress(css) do
      {:ok, compressed} ->
        hash = Base.encode16(:crypto.hash(:md5, css), case: :lower)
        true = :ets.insert(:beacon_assets, {{site, :css}, {hash, css, compressed}})
        :ok

      error ->
        raise Beacon.LoaderError, "failed to compress css: #{inspect(error)}"
    end
  end

  @doc false
  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :css}, {:"$1", :_, :_}}) do
      [[hash]] -> hash
      _ -> ""
    end
  end
end
