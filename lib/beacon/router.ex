# https://github.com/phoenixframework/phoenix/blob/8ab705603ac695779bf40668b0c63a46ebcc19e5/lib/phoenix/router.ex
# https://github.com/phoenixframework/phoenix_live_dashboard/blob/3d78c73721ae8db2e501abf51fcc1f7796be0649/lib/phoenix/live_dashboard/router.ex

defmodule Beacon.Router do
  @moduledoc """
  Provides routing helpers to instantiate sites, admin interface, or api endpoints.

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
      Module.register_attribute(__MODULE__, :beacon_admin_prefix, accumulate: false)
      import Beacon.Router, only: [beacon_site: 2, beacon_admin: 1, beacon_admin: 2, beacon_api: 1]
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    sites = Module.get_attribute(env.module, :beacon_sites)

    prefixes =
      for {site, prefix} <- sites do
        quote do
          @doc false
          def __beacon_site_prefix__(unquote(site)), do: unquote(prefix)
        end
      end

    admin_prefix = Module.get_attribute(env.module, :beacon_admin_prefix)

    quote do
      @doc false
      def __beacon_sites__, do: unquote(Macro.escape(sites))
      def __beacon_admin_prefix__, do: unquote(Macro.escape(admin_prefix))
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
  defmacro beacon_site(path, opts) do
    quote bind_quoted: binding(), location: :keep do
      scope path, alias: false, as: false do
        {session_name, session_opts} = Beacon.Router.__options__(opts)

        live_session session_name, session_opts do
          get "/beacon_static/css-:md5", BeaconWeb.BeaconStaticController, :css, as: :beacon_static_asset, assigns: %{site: opts[:site]}
          get "/beacon_static/js:md5", BeaconWeb.BeaconStaticController, :js, as: :beacon_static_asset, assigns: %{site: opts[:site]}
          get "/beacon_assets/:asset", BeaconWeb.MediaLibraryController, :show
          live "/*path", BeaconWeb.PageLive, :path
        end
      end

      @beacon_sites {opts[:site], Phoenix.Router.scoped_path(__MODULE__, path)}
    end
  end

  @doc false
  def __options__(opts) do
    {site, _opts} = Keyword.pop(opts, :site)

    site =
      cond do
        site == :beacon_admin ->
          raise ArgumentError, ":beacon_admin is a reserved site name."

        site && is_atom(opts[:site]) ->
          opts[:site]

        :invalid ->
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
  Admin routes for a beacon site.

  ## Examples

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Beacon.Router

        scope "/", MyAppWeb do
          pipe_through :browser
          beacon_admin "/admin", on_mount: [SomeHook]
        end
      end

  ## Options

    * `:on_mount` (optional) , an optional list of `on_mount` hooks passed to `live_session`.
    This will allow for authenticated routes, among other uses.
  """
  defmacro beacon_admin(path, opts \\ []) do
    quote bind_quoted: binding(), location: :keep do
      # check before scope so it can raise with the proper message
      if existing = Module.get_attribute(__MODULE__, :beacon_admin_prefix) do
        raise ArgumentError, """
        Only one declaration of beacon_admin/1 is allowed per router.

        Can't add #{inspect(path)} when #{inspect(existing)} is already defined.
        """
      else
        @beacon_admin_prefix Phoenix.Router.scoped_path(__MODULE__, path)
      end

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

        session_opts = Beacon.Router.__admin_session_opts__(opts)

        live_session :beacon_admin, session_opts do
          get "/beacon_static/css-:md5", BeaconWeb.BeaconStaticController, :css, as: :beacon_admin_static_asset
          get "/beacon_static/js:md5", BeaconWeb.BeaconStaticController, :js, as: :beacon_admin_static_asset

          live "/", BeaconWeb.Admin.HomeLive.Index, :index
          live "/pages", BeaconWeb.Admin.PageLive.Index, :index
          live "/pages/new", BeaconWeb.Admin.PageLive.Index, :new
          live "/page_editor/:id", BeaconWeb.Admin.PageEditorLive, :edit
          live "/media_library", BeaconWeb.Admin.MediaLibraryLive.Index, :index
          live "/media_library/upload", BeaconWeb.Admin.MediaLibraryLive.Index, :upload
        end
      end
    end
  end

  @doc false
  def __admin_session_opts__(opts) do
    if Keyword.has_key?(opts, :root_layout) do
      raise ArgumentError, """
      You cannot assign a different root_layout.

      Beacon Admin depends on {BeaconWeb.Layouts, :admin}
      """
    end

    if Keyword.has_key?(opts, :layout) do
      raise ArgumentError, """
      You cannot assign a layout.

      Beacon Admin depends on {BeaconWeb.Layouts, :admin}
      """
    end

    on_mounts = get_on_mount_list(Keyword.get(opts, :on_mount, []))

    [
      on_mount: on_mounts,
      root_layout: {BeaconWeb.Layouts, :admin}
    ]
  end

  defp get_on_mount_list(on_mounts) when is_list(on_mounts) do
    if Enum.member?(on_mounts, BeaconWeb.Admin.Hooks.AssignAgent) do
      on_mounts
    else
      on_mounts ++ [BeaconWeb.Admin.Hooks.AssignAgent]
    end
  end

  defp get_on_mount_list(on_mounts) do
    raise ArgumentError, """
    expected `on_mount` option to be a list.

    Got: #{inspect(on_mounts)}
    """
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
  def beacon_asset_path(%Beacon.BeaconAttrs{} = attrs, file_name) do
    %{site: site, prefix: prefix} = attrs
    sanitize_path("/#{prefix}/beacon_assets/#{file_name}?site=#{site}")
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
    path = build_path_with_prefix(prefix, path)
    params = for {key, val} <- params, do: {key, val}

    Phoenix.VerifiedRoutes.unverified_path(socket, socket.router, path, params)
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
  def add_page(site, path, {_page_id, _layout_id, _template_ast, _page_module, _component_module} = metadata) do
    add_page(:beacon_pages, site, path, metadata)
  end

  @doc false
  def add_page(table, site, path, {_page_id, _layout_id, _template_ast, _page_module, _component_module} = metadata) do
    :ets.insert(table, {{site, path}, metadata})
  end

  @doc false
  def del_page(site, path) do
    :ets.delete(:beacon_pages, {site, path})
  end

  @doc false
  def dump_pages do
    case :ets.match(:beacon_pages, :"$1") do
      [] -> []
      [pages] -> pages
    end
  end

  @doc false
  def lookup_path(site, path) do
    lookup_path(:beacon_pages, site, path)
  end

  # Lookup for a path stored in ets that is coming from a live view.
  #
  # Note that the `path` is the full expanded path coming from the request at runtime,
  # while the path stored in the ets table is the page path stored at compile time.
  # That means a page path with dynamic parts like `/posts/*slug` in ets is received here as `/posts/my-post`,
  # and to make this lookup find the correct record in ets, we have to take some rules into account:
  #
  # Paths with only static segments
  # - lookup static paths by key and return early if found a match
  #
  # Paths with dynamic segments:
  # - catch-all "*" -> ignore segments after catch-all
  # - variable ":" -> traverse the whole path ignoring ":" segments
  #
  @doc false
  def lookup_path(table, site, path, limit \\ 10)

  def lookup_path(table, site, path_info, limit) when is_atom(site) and is_list(path_info) and is_integer(limit) do
    if route = match_static_routes(table, site, path_info) do
      route
    else
      match_dynamic_routes(:ets.match(table, :"$1", limit), path_info)
    end
  end

  @doc false
  def lookup_path(_table, _site, _path, _limit), do: nil

  defp match_static_routes(table, site, path_info) do
    path =
      if path_info == [] do
        ""
      else
        Enum.join(path_info, "/")
      end

    match = {{site, path}, :_}
    guards = []
    body = [:"$_"]

    case :ets.select(table, [{match, guards, body}]) do
      [match] -> match
      _ -> nil
    end
  end

  defp match_dynamic_routes(:"$end_of_table", _path_info) do
    nil
  end

  defp match_dynamic_routes({routes, :"$end_of_table"}, path_info) do
    route =
      Enum.find(routes, fn [{{_site, page_path}, _metadata}] ->
        match_path?(page_path, path_info)
      end)

    case route do
      [route] -> route
      _ -> nil
    end
  end

  defp match_dynamic_routes({routes, cont}, path_info) do
    route =
      Enum.find(routes, fn [{{_site, page_path}, _metadata}] ->
        match_path?(page_path, path_info)
      end)

    case route do
      [route] -> route
      _ -> match_dynamic_routes(:ets.match(cont), path_info)
    end
  end

  # compare `page_path` with `path_info` considering dynamic segments
  # page_path is the value from beacon_pages.path and it contains
  # the compile-time path, including dynamic segments, for eg: /posts/*slug
  # while path_info is the expanded value coming from the live view request,
  # eg: /posts/my-new-post
  defp match_path?(page_path, path_info) do
    has_catch_all? = String.contains?(page_path, "/*")
    page_path = String.split(page_path, "/", trim: true)
    page_path_length = length(page_path)
    path_info_length = length(path_info)

    {_, match?} =
      Enum.reduce_while(path_info, {0, false}, fn segment, {position, _match?} ->
        matching_segment = Enum.at(page_path, position)

        cond do
          page_path_length > path_info_length && has_catch_all? -> {:halt, {position, false}}
          is_nil(matching_segment) -> {:halt, {position, false}}
          String.starts_with?(matching_segment, "*") -> {:halt, {position, true}}
          String.starts_with?(matching_segment, ":") -> {:cont, {position + 1, true}}
          segment == matching_segment -> {:cont, {position + 1, true}}
          :no_match -> {:halt, {position, false}}
        end
      end)

    match?
  end
end
