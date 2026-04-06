defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime CSS for a site. Compiled on first request via `Beacon.Cache`,
  stampede-safe — exactly one process compiles while others wait.
  """

  require Logger
  alias Beacon.Types.Site

  @callback config(site :: Site.t()) :: String.t()
  @callback compile(site :: Site.t()) :: {:ok, String.t()} | {:error, any()}

  @doc false
  def config(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.config(site)
  end

  @doc false
  def compile(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.compile(site)
  end

  @doc false
  def fetch(site, version \\ :brotli)
  def fetch(site, :brotli), do: do_fetch(site, {:_, :"$1", :_})
  def fetch(site, :gzip), do: do_fetch(site, {:_, :_, :"$1"})

  def fetch(site, :deflate) do
    ensure_compiled(site)

    case :ets.match(:beacon_assets, {{site, :css}, {:_, :_, :"$1"}}) do
      [[gzipped]] when is_binary(gzipped) -> :zlib.gunzip(gzipped)
      _ -> "/* CSS compilation failed */"
    end
  end

  defp do_fetch(site, guard) do
    ensure_compiled(site)

    case :ets.match(:beacon_assets, {{site, :css}, guard}) do
      [[css]] -> css
      _ -> "/* CSS compilation failed */"
    end
  end

  @doc false
  def load!(site) do
    css =
      case compile(site) do
        {:ok, css} -> css
        {:error, error} -> raise Beacon.LoaderError, "failed to compile css: #{inspect(error)}"
      end

    hash = Base.encode16(:crypto.hash(:md5, css), case: :lower)

    brotli =
      case ExBrotli.compress(css) do
        {:ok, content} -> content
        _ -> nil
      end

    gzip = :zlib.gzip(css)

    true = :ets.insert(:beacon_assets, {{site, :css}, {hash, brotli, gzip}})
    :ok
  end

  @doc false
  def current_hash(site) do
    ensure_compiled(site)

    case :ets.match(:beacon_assets, {{site, :css}, {:"$1", :_, :_}}) do
      [[hash]] -> hash
      _ -> nil
    end
  end

  defp ensure_compiled(site) do
    Beacon.Cache.fetch(:beacon_assets, {site, :css_compile}, fn ->
      load!(site)
    end)
  end
end
