# https://github.com/phoenixframework/phoenix_live_dashboard/blob/3d78c73721ae8db2e501abf51fcc1f7796be0649/lib/phoenix/live_dashboard/router.ex

defmodule Beacon.Router do
  @moduledoc """
  Provides routing helpers to instantiate sites, admin interface, or api endpoints.

  In your app router, add `import Beacon.Router` and call one the of the available macros.
  """

  @doc """
  Routes for a beacon site.

  ## Examples

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import Beacon.Router

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
  defmacro beacon_site(path, opts \\ []) do
    quote bind_quoted: binding() do
      scope path, BeaconWeb do
        {session_name, session_opts} = Beacon.Router.__options__(opts)

        live_session session_name, session_opts do
          get "/beacon_assets/:asset", MediaLibraryController, :show
          live "/*path", PageLive, :path
        end
      end

      unless Module.get_attribute(__MODULE__, :beacon_static_defined) do
        Module.put_attribute(__MODULE__, :beacon_static_defined, true)

        scope "/beacon_static", as: false, alias: false do
          get "/*resource", BeaconWeb.BeaconStaticController, only: [:index]
        end
      end

      @beacon_site opts[:site]
      def __beacon_site__, do: @beacon_site

      @beacon_site_prefix Phoenix.Router.scoped_path(__MODULE__, path)
      def __beacon_site_prefix__, do: @beacon_site_prefix
    end
  end

  @doc false
  def __options__(opts) do
    {site, _opts} = Keyword.pop(opts, :site)

    site =
      if site && is_atom(opts[:site]) do
        opts[:site]
      else
        raise ArgumentError, ":site must be an atom, got: #{inspect(opts[:site])}"
      end

    {
      # TODO: sanitize and format session name
      String.to_atom("beacon_#{site}"),
      [
        session: %{"beacon_site" => site},
        root_layout: {BeaconWeb.Layouts, :runtime}
      ]
    }
  end

  @doc """
  Admin routes.
  """
  defmacro beacon_admin(path) do
    quote bind_quoted: binding() do
      scope path, BeaconWeb.Admin do
        import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

        live_session :beacon_admin, root_layout: {BeaconWeb.Layouts, :admin} do
          live "/", HomeLive.Index, :index
          live "/pages", PageLive.Index, :index
          live "/pages/new", PageLive.Index, :new
          live "/page_editor/:id", PageEditorLive, :edit
          live "/media_library", MediaLibraryLive.Index, :index
          live "/media_library/upload", MediaLibraryLive.Index, :upload
        end
      end

      unless Module.get_attribute(__MODULE__, :beacon_static_defined) do
        Module.put_attribute(__MODULE__, :beacon_static_defined, true)

        scope "/beacon_static", as: false, alias: false do
          get "/*resource", BeaconWeb.BeaconStaticController, only: [:index]
        end
      end

      @beacon_admin_prefix Phoenix.Router.scoped_path(__MODULE__, path)
      def __beacon_admin_prefix__, do: @beacon_admin_prefix
    end
  end

  @doc """
  API routes.
  """
  defmacro beacon_api(path) do
    quote bind_quoted: binding() do
      scope path, BeaconWeb.AdminApi do
        import Phoenix.Router, only: [get: 3, post: 3, put: 3]

        get "/pages", PageController, :index
        get "/pages/:id", PageController, :show
        post "/pages", PageController, :create
        put "/pages/:id", PageController, :update_page_pending
        post "/pages/:id/publish", PageController, :publish

        get "/layouts", LayoutController, :index
        get "/layouts/:id", LayoutController, :show
      end
    end
  end

  # TODO: secure cross site assets
  @doc """
  Router helper to resolve asset path for sites.

  ## Examples

      scope "/" do
        beacon_site "/", site: :my_site
      end

      iex> beacon_asset_path(beacon_attrs, "logo.jpg")
      "/beacon_assets/log.jpg?site=my_site"


      scope "/parent" do
        scope "/nested" do
          beacon_site "/my_site", site: :my_site
        end
      end

      iex> beacon_asset_path(beacon_attrs, "logo.jpg")
      "/parent/nested/my_site/beacon_assets/logo.jpg?site=my_site"

  Note that `@beacon_attrs` assign is injected and available in pages automatically.
  """
  @spec beacon_asset_path(Beacon.BeaconAttrs.t(), Path.t()) :: String.t()
  def beacon_asset_path(beacon_attrs, file_name) do
    site = beacon_attrs.router.__beacon_site__()
    sanitize_path(beacon_attrs.router.__beacon_site_prefix__() <> "/beacon_assets/#{file_name}?site=#{site}")
  end

  @doc """
  Router helper to generate admin paths relative to the current scope.

  ## Examples

      scope "/" do
        beacon_admin "/admin"
      end

      iex> beacon_admin_path(@socket, "/pages")
      "/admin/pages"


      scope "/parent" do
        scope "/nested" do
          beacon_admin "/admin"
        end
      end

      iex> beacon_admin_path(@socket, "/pages", %{active: true})
      "/parent/nested/admin/pages?active=true
  """
  def beacon_admin_path(socket, path, params \\ %{}) do
    prefix = socket.router.__beacon_admin_prefix__()
    path = sanitize_path("#{prefix}/#{path}")
    params = for {key, val} <- params, do: {key, val}

    Phoenix.VerifiedRoutes.unverified_path(socket, socket.router, path, params)
  end

  @doc false
  def sanitize_path(path) do
    String.replace(path, "//", "/")
  end

  @doc false
  def add_page(site, path, {_, _, _} = value) do
    add_page(:beacon_routes, site, path, value)
  end

  @doc false
  def add_page(table, site, path, value) do
    :ets.insert(table, {{site, path}, value})
  end

  @doc false
  def lookup_key(site, path) do
    [{_, value}] = :ets.lookup(:beacon_routes, {site, path})
    value
  end

  @doc false
  def lookup_path(site, path) do
    lookup_path(:beacon_routes, site, path)
  end

  # Lookup for a path stored in ets that is coming from a live view.
  #
  # Note that the `path` is the full expanded path coming from the request at runtime,
  # while the path stored in the ets table is the page path stored at compile time.
  # That means a page path with dynamic parts like `/posts/*slug` in ets is received here as `/posts/my-post`,
  # and to make this lookup find the correct record in ets, we have to take some rules into account:
  #
  # - return exact matches right away
  # -
  @doc false
  def lookup_path(table, site, path) when is_atom(site) and is_list(path) do
    # TODO: dynamic parts
    path =
      if path == [] do
        ""
      else
        Enum.join(path, "/")
      end

    match = {{site, path}, :_}
    guards = []
    body = [:"$_"]

    case :ets.select(table, [{match, guards, body}]) do
      [] -> nil
      [match] -> match
    end
  end

  @doc false
  def lookup_path(_table, _site, _path), do: nil
end
