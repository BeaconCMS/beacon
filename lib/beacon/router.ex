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
          beacon_site "/blog", name: "blog", data_source: MyApp.BlogDataSource
        end
      end

  Note that you may have multiple sites in the same scope or
  separated in multiple scopes, which allows you to pipe
  your sites through custom pipelines, for eg is your site
  requires some sort of authentication:

      scope "/protected", MyAppWeb do
          pipe_through :browser
          pipe_through :auth
          beacon_site "/sales", name: "stats"
        end
      end

  ## Options

    * `:name` (required) - identify your site name.
    * `:data_source` (optional) - module that implements `Beacon.DataSource`
      to provide assigns to pages.
    * `:live_socket_path` (optional) - path to live view socket, defaults to `/live`.

  """
  defmacro beacon_site(path, opts \\ []) do
    quote bind_quoted: binding() do
      scope path, BeaconWeb do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        {session_name, session_opts, route_opts} = o = Beacon.Router.__options__(opts)

        live_session session_name, session_opts do
          live "/*path", PageLive, :path, route_opts
        end
      end
    end
  end

  @doc false
  def __options__(opts) do
    live_socket_path = Keyword.get(opts, :live_socket_path, "/live")

    name =
      if is_bitstring(opts[:name]) do
        opts[:name]
      else
        raise ArgumentError, ":name must be a string, got: #{inspect(opts[:name])}"
      end

    {
      # TODO: sanitize and format session name
      String.to_atom("beacon_" <> name),
      [
        session: %{"beacon_site" => name, "beacon_data_source" => opts[:data_source]},
        root_layout: {BeaconWeb.Layouts, :runtime}
      ],
      [
        private: %{beacon: %{live_socket_path: live_socket_path}}
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
          live "/pages", PageLive.Index, :index
          live "/pages/new", PageLive.Index, :new
          live "/page_editor/:id", PageEditorLive, :edit
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

  @doc """
  Router helper to generate admin paths.

  Prefix is added automatically based on the current router scope.
  """
  def beacon_admin_path(socket, path, params \\ %{}) do
    prefix = socket.router.__beacon_admin_prefix__()
    path = String.replace("#{prefix}/#{path}", "//", "/")
    params = for {key, val} <- params, do: {key, val}

    Phoenix.VerifiedRoutes.unverified_path(socket, socket.router, path, params)
  end
end
