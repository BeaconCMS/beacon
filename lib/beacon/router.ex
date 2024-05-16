# https://github.com/phoenixframework/phoenix/blob/8ab705603ac695779bf40668b0c63a46ebcc19e5/lib/phoenix/router.ex
# https://github.com/phoenixframework/phoenix_live_dashboard/blob/3d78c73721ae8db2e501abf51fcc1f7796be0649/lib/phoenix/live_dashboard/router.ex

defmodule Beacon.Router do
  @moduledoc """
  Provides routing helpers to instantiate sites, or api endpoints.

  In your app router, add `use Beacon.Router` and call one the of the available macros.
  """

  defmacro __using__(_opts) do
    quote do
      unquote(prelude())
    end
  end

  defp prelude do
    quote do
      Module.register_attribute(__MODULE__, :beacon_sites, accumulate: true)
      import Beacon.Router, only: [beacon_site: 2, beacon_api: 1]
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    sites = Module.get_attribute(env.module, :beacon_sites)

    prefixes =
      for {site, scoped_prefix} <- sites do
        quote do
          @doc false
          def __beacon_scoped_prefix_for_site__(unquote(site)), do: unquote(scoped_prefix)
        end
      end

    quote do
      @doc false
      def __beacon_sites__, do: unquote(Macro.escape(sites))
      unquote(prefixes)
    end
  end

  @doc """
  Routes for a beacon site.

  ## Examples

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Beacon.Router

        scope "/", MyAppWeb do
          pipe_through :browser
          beacon_site "/blog", site: :blog
        end
      end

  Note that you may have multiple sites in the same scope or
  separated in multiple scopes, which allows you to pipe
  your sites through custom pipelines, for eg is your site
  requires some sort of authentication:

      scope "/protected", MyAppWeb do
          pipe_through :browser
          pipe_through :auth
          beacon_site "/sales", site: :stats
        end
      end

  ## Options

    * `:site` (required) `t:Beacon.Config.site/0` - register your site with a unique name,
      note that has to be the same name used for configuration, see `Beacon.Config` for more info.
  """
  defmacro beacon_site(prefix, opts) do
    # TODO: raise on duplicated sites defined on the same prefix
    quote bind_quoted: binding(), location: :keep do
      import Phoenix.Router, only: [scope: 3, get: 3, get: 4]
      import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

      {site, session_name, session_opts} = Beacon.Router.__options__(opts)

      get "/beacon_assets/#{site}/:file_name", BeaconWeb.MediaLibraryController, :show

      scope prefix, alias: false, as: false do
        live_session session_name, session_opts do
          get "/beacon_assets/css-:md5", BeaconWeb.AssetsController, :css, as: :beacon_asset, assigns: %{site: opts[:site]}
          get "/beacon_assets/js:md5", BeaconWeb.AssetsController, :js, as: :beacon_asset, assigns: %{site: opts[:site]}
          get "/beacon_assets/:file_name", BeaconWeb.MediaLibraryController, :show
          live "/*path", BeaconWeb.PageLive, :path
        end
      end

      @beacon_sites {opts[:site], Phoenix.Router.scoped_path(__MODULE__, prefix)}
    end
  end

  @doc false
  def __options__(opts) do
    {site, _opts} = Keyword.pop(opts, :site)

    site =
      cond do
        String.starts_with?(Atom.to_string(site), ["beacon", "__beacon"]) ->
          raise ArgumentError, ":site can not start with beacon or __beacon, got: #{site}"

        site && is_atom(opts[:site]) ->
          opts[:site]

        :invalid ->
          raise ArgumentError, ":site must be an atom, got: #{inspect(opts[:site])}"
      end

    {
      site,
      # TODO: sanitize and format session name
      String.to_atom("beacon_#{site}"),
      [
        session: %{"beacon_site" => site},
        root_layout: {BeaconWeb.Layouts, :runtime}
      ]
    }
  end

  @doc """
  API routes.
  """
  defmacro beacon_api(path) do
    quote bind_quoted: binding() do
      scope path, BeaconWeb.API do
        import Phoenix.Router, only: [get: 3, post: 3, put: 3]

        get "/:site/pages", PageController, :index
        get "/:site/pages/:page_id", PageController, :show
        put "/:site/pages/:page_id", PageController, :update
        get "/:site/pages/:page_id/components/:component_id", ComponentController, :show_ast
        get "/:site/components", ComponentController, :index
        get "/:site/components/:component_id", ComponentController, :show
      end
    end
  end

  # TODO: secure cross site assets
  @doc """
  Router helper to generate the asset path.

  ## Example

      iex> beacon_asset_path(:my_site_com, "logo.jpg")
      "/beacon_assets/my_site_com/logo.jpg"

  """
  @spec beacon_asset_path(Beacon.Types.Site.t(), Path.t()) :: String.t()
  def beacon_asset_path(site, file_name) when is_atom(site) and is_binary(file_name) do
    sanitize_path("/beacon_assets/#{site}/#{file_name}")
  end

  @doc """
  Router helper to generate the asset url.

  ## Example

      iex> beacon_asset_url(:my_site_com, "logo.jpg")
      "https://site.com/beacon_assets/my_site_com/logo.jpg"

  """
  @spec beacon_asset_url(Beacon.Types.Site.t(), Path.t()) :: String.t()
  def beacon_asset_url(site, file_name) when is_atom(site) and is_binary(file_name) do
    Beacon.Config.fetch!(site).endpoint.url() <> beacon_asset_path(site, file_name)
  end

  @doc false
  def build_path_with_prefix(prefix, "/") do
    prefix
  end

  def build_path_with_prefix(prefix, path) do
    sanitize_path("#{prefix}/#{path}")
  end

  def sanitize_path(path) do
    String.replace(path, "//", "/")
  end

  @doc false
  def path_params(page_path, path_info) when is_binary(page_path) and is_list(path_info) do
    page_path = for segment <- String.split(page_path, "/"), segment != "", do: segment

    Enum.zip_reduce(page_path, path_info, %{}, fn
      ":" <> segment, value, acc ->
        Map.put(acc, segment, value)

      "*" <> segment, value, acc ->
        position = Enum.find_index(path_info, &(&1 == value))
        Map.put(acc, segment, Enum.drop(path_info, position))

      _, _, acc ->
        acc
    end)
  end
end
