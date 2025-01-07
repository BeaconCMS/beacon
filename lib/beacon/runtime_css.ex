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
  @spec asset_url(Site.t()) :: String.t()
  def asset_url(site) do
    %{endpoint: endpoint, router: router} = Beacon.Config.fetch!(site)
    prefix = router.__beacon_scoped_prefix_for_site__(site)
    endpoint.url() <> Beacon.Router.sanitize_path("#{prefix}/__beacon_assets__/css_config")
  end

  @doc false
  def compile(site) when is_atom(site) do
    Beacon.Config.fetch!(site).css_compiler.compile(site)
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
