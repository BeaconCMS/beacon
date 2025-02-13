defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Compiles the CSS for a site using the compiler defined in `t:Beacon.Config.css_compiler/0`

  Beacon supports Tailwind by default implemented by `Beacon.RuntimeCSS.TailwindCompiler`,
  you can use that module as template to implement any ther CSS engine as needed.
  """

  require Logger
  alias Beacon.Types.Site

  @doc """
  Returns the CSS compiler config.

  For Tailwind that would be the content of the tailwind config file,
  or return an empty string `""` if the provided engine doesn't have a config file.
  """
  @callback config(site :: Site.t()) :: String.t()

  @doc """
  Executes the compilation to generate the CSS for the site using the provided `:css_compiler` in `Beacon.Config`.
  """
  @callback compile(site :: Site.t()) :: {:ok, String.t()} | {:error, any()}

  @doc false
  # TODO: compress and fetch from ETS
  def config(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.config(site)
  end

  @doc """
  Returns the URL to fetch the CSS config used to generate the site stylesheet.
  """
  @spec css_config_url(Site.t()) :: String.t()
  def css_config_url(site) do
    routes_module = Beacon.Loader.fetch_routes_module(site)
    Beacon.apply_mfa(site, routes_module, :public_css_config_url, [])
  end

  @doc false
  def compile(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.compile(site)
  end

  @doc false
  def fetch(site, version \\ :brotli)
  def fetch(site, :brotli), do: do_fetch(site, {:_, :_, :"$1", :_})
  def fetch(site, :gzip), do: do_fetch(site, {:_, :_, :_, :"$1"})
  def fetch(site, :deflate), do: do_fetch(site, {:_, :"$1", :_, :_})

  defp do_fetch(site, guard) do
    case :ets.match(:beacon_assets, {{site, :css}, guard}) do
      [[css]] -> css
      _ -> "/* CSS not found for site #{inspect(site)} */"
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

    try do
      true = :ets.insert(:beacon_assets, {{site, :css}, {hash, css, brotli, gzip}})
    rescue
      _ -> reraise Beacon.LoaderError, [message: "failed to compress css"], __STACKTRACE__
    end

    :ok
  end

  @doc false
  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :css}, {:"$1", :_, :_, :_}}) do
      [[hash]] ->
        hash

      found ->
        Logger.warning("""
        failed to fetch current css hash

        Got:

          #{inspect(found)}
        """)

        nil
    end
  end
end
