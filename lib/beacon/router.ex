# https://github.com/phoenixframework/phoenix/blob/8ab705603ac695779bf40668b0c63a46ebcc19e5/lib/phoenix/router.ex
# https://github.com/phoenixframework/phoenix_live_dashboard/blob/3d78c73721ae8db2e501abf51fcc1f7796be0649/lib/phoenix/live_dashboard/router.ex

defmodule Beacon.Router do
  @moduledoc """
  Controls pages routing and provides helpers to mount sites in your application router and generate links to pages.

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Beacon.Router

        scope "/", MyAppWeb do
          pipe_through :browser
          beacon_site "/blog", site: :blog
        end
      end

  ## Helpers

  A `~p` sigil is provided to generate links to pages taking the `scope` and site `prefix` into account.

  Using that sigil in a template in the `:blog` site defined above would result in the following links:

  ```
  ~p"/contact" => "/blog/contact"
  ~p"/posts/\#\{\@post\}" => "/blog/posts/my-post"
  ```

  In this example `post` is a `Beacon.Content.Page` that implements the `Phoenix.Param` protocol to resolve the page path.

  ## Path

  The full path of the site is calculated resolving the `scope` prefix plus the site `prefix`.

  The simplest scenario is mounting a site at the root of your application:

      scope "/", MyAppWeb do
        pipe_through :browser
        beacon_site "/", site: :my_site
      end

  In this case the site `:my_site` will be available at `https://yourapp.com/`

  By mixing prefixes you have the flexibility to mount sites in different paths,
  for example both declarations below will mount the site at `https://yourapp.com/blog`:

      scope "/blog", MyAppWeb do
        pipe_through :browser
        beacon_site "/", site: :blog
      end

      scope "/", MyAppWeb do
        pipe_through :browser
        beacon_site "/blog", site: :blog
      end

  There's no difference between the two approaches, but that is important to group and organize your routes and sites,
  for example a scope might be served through a different pipeline:application

      scope "/marketing", MyAppWeb do
        pipe_through :browser_analytics
        beacon_site "/super-campaign", site: :marketing_super_campaign
        beacon_site "/", site: :marketing
      end

  Note in the last example that `/super-campaign` is defined _before_ `/` and there's an important reason for that: router precedence.

  ## Route Precedence

  Beacon pages are defined dynamically so it doesn't know which pages are availale when the router is compiled,
  which means that any route after the `prefix` may match a published page. For example `/contact` may be a valid
  page published under the mounted `beacon_site "/, site: :marketing` site.

  Essentially it mounts a catch-all route like `/*` so if we had inverted the routes below we would end with:application

      /*
      /super-campaign

  The second route would never match since the first one would match all requests.

  As a rule of thumb, put all specific routes first.

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
  Mounts a site in the `prefix` in your host application router.

  ## Options

    * `:site` (required) `t:Beacon.Types.Site.t/0` - register your site with a unique name.
      Note that the name has to match the one used in your site configuration in `application.ex`.
      See the module doc and `Beacon.Config` for more info.

  """
  defmacro beacon_site(prefix, opts) do
    # TODO: raise on duplicated sites defined on the same prefix
    quote bind_quoted: binding(), location: :keep do
      import Phoenix.Router, only: [scope: 3, get: 3, get: 4]
      import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

      {site, session_name, session_opts} = Beacon.Router.__options__(opts)

      get "/__beacon_assets__/#{site}/:file_name", BeaconWeb.MediaLibraryController, :show

      scope prefix, alias: false, as: false do
        live_session session_name, session_opts do
          # TODO: css_config-:md5 caching
          get "/__beacon_assets__/css_config", BeaconWeb.AssetsController, :css_config, as: :beacon_asset, assigns: %{site: opts[:site]}
          get "/__beacon_assets__/css-:md5", BeaconWeb.AssetsController, :css, as: :beacon_asset, assigns: %{site: opts[:site]}
          get "/__beacon_assets__/js-:md5", BeaconWeb.AssetsController, :js, as: :beacon_asset, assigns: %{site: opts[:site]}
          get "/__beacon_assets__/:file_name", BeaconWeb.MediaLibraryController, :show
          live "/*path", BeaconWeb.PageLive, :path
        end
      end

      @beacon_sites {opts[:site], Phoenix.Router.scoped_path(__MODULE__, prefix)}
    end
  end

  @doc false
  @spec __options__(keyword()) :: {atom(), atom(), keyword()}
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

    session_opts = build_session_opts(opts, site)

    {
      site,
      # TODO: sanitize and format session name
      String.to_atom("beacon_#{site}"),
      session_opts
    }
  end

  defp build_session_opts(opts, site) do
    root_layout =
      case Keyword.pop(opts, :root_layout) do
        {nil, _opts} ->
          {BeaconWeb.Layouts, :runtime}

        {root_layout, _opts} ->
          root_layout
      end

    default_session_opts = [
      session: %{"beacon_site" => site},
      root_layout: root_layout
    ]

    case Keyword.pop(opts, :on_mount) do
      {nil, _opts} ->
        default_session_opts

      {on_mount, _opts} ->
        Keyword.merge(default_session_opts, on_mount: on_mount)
    end
  end

  @doc false
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

  @doc false
  def beacon_asset_path(site, file_name) when is_atom(site) and is_binary(file_name) do
    sanitize_path("/__beacon_assets__/#{site}/#{file_name}")
  end

  @doc false
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

  @doc false
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
