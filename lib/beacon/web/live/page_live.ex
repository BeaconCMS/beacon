defmodule Beacon.Web.PageLive do
  @moduledoc false

  use Beacon.Web, :live_view
  require Logger
  import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3], warn: false
  import Beacon.Web, only: [assign: 2, assign: 3, assign_new: 3], warn: false
  alias Beacon.Lifecycle
  alias Beacon.Loader
  alias Beacon.RouterServer
  alias Beacon.Web.BeaconAssigns
  alias Phoenix.Component

  def mount(:not_mounted_at_router, _params, socket) do
    {:ok, socket}
  end

  def mount(params, session, socket) do
    %{"path" => path} = params
    %{"beacon_site" => site} = session

    if Beacon.Config.fetch!(site).mode == :live and connected?(socket) do
      :ok = Beacon.PubSub.subscribe_to_page(site, path)
    end

    variant_roll =
      case session["beacon_variant_roll"] do
        nil ->
          Logger.warning("""
          Beacon.Plug is missing from the Router pipeline.

          Page Variants will not be used.
          """)

          nil

        roll ->
          roll
      end

    page = RouterServer.lookup_page!(site, path)
    socket = Component.assign(socket, beacon: BeaconAssigns.new(site, page, variant_roll))

    {:ok, socket, layout: {Beacon.Web.Layouts, :dynamic}}
  end

  def render(assigns) do
    %{beacon: %{site: site, private: %{page_module: page_module}}} = assigns

    # do not allow overwritring site to avoid rendering a leaked page
    %{site: ^site} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site]])

    site
    |> Beacon.apply_mfa(page_module, :page, [])
    |> Lifecycle.Template.render_template(assigns, __ENV__)
  end

  def handle_info({:page_loaded, _}, socket) do
    # TODO: disable automatic template reload (repaint) in favor of https://github.com/BeaconCMS/beacon/issues/179

    socket =
      socket
      # |> BeaconAssigns.update_private(:page_updated_at, DateTime.utc_now())
      # |> assign(:page_title, page_title(params, socket.assigns))
      |> push_event("beacon:page-updated", %{
        meta_tags: Beacon.Web.DataSource.meta_tags(socket.assigns)
        # runtime_css_path: Beacon.Web.Layouts.asset_path(socket, :css)
      })

    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    %{beacon: %{site: site, private: %{page_module: page_module, live_path: live_path, info_handlers_module: info_handlers_module}}} = socket.assigns
    %{site: ^site, id: page_id} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site, :id]])

    result =
      Beacon.apply_mfa(
        site,
        info_handlers_module,
        :handle_info,
        [msg, socket],
        context: %{site: site, page_id: page_id, live_path: live_path}
      )

    case result do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      other ->
        raise Beacon.Web.ServerError,
              "handle_info for #{live_path} expected return of {:noreply, %Phoenix.LiveView.Socket{}}, but got #{inspect(other)}"
    end
  end

  def handle_event(event_name, event_params, socket) do
    %{beacon: %{site: site, private: %{page_module: page_module, live_path: live_path, event_handlers_module: event_handlers_module}}} =
      socket.assigns

    %{site: ^site, id: page_id} = Beacon.apply_mfa(site, page_module, :page_assigns, [[:site, :id]])

    result =
      Beacon.apply_mfa(
        site,
        event_handlers_module,
        :handle_event,
        [event_name, event_params, socket],
        context: %{site: site, page_id: page_id, live_path: live_path}
      )

    case result do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      other ->
        raise Beacon.Web.ServerError,
              "handle_event for #{live_path} expected return of {:noreply, %Phoenix.LiveView.Socket{}}, but got #{inspect(other)}"
    end
  end

  def handle_params(params, url, socket) do
    case Beacon.Private.site_from_session(socket.endpoint, socket.router, url, __MODULE__) do
      nil ->
        raise Beacon.Web.NotFoundError, """
        no page found for url #{url}

        Make sure a page was created for that url.
        """

      site ->
        %{"path" => path_info} = params

        if socket.assigns.beacon.site != site do
          if Beacon.Config.fetch!(site).mode == :live do
            Beacon.PubSub.unsubscribe_to_page(socket.assigns.beacon.site, path_info)
            Beacon.PubSub.subscribe_to_page(site, path_info)
          end
        end

        page = RouterServer.lookup_page!(site, path_info)
        live_data = Beacon.Web.DataSource.live_data(site, path_info, Map.drop(params, ["path"]))
        beacon_assigns = BeaconAssigns.new(site, page, live_data, path_info, params, :beacon, socket.assigns.beacon.private.variant_roll)

        socket =
          socket
          |> Component.assign(live_data)
          # TODO: remove deprecated @beacon_live_data
          |> Component.assign(:beacon_live_data, live_data)
          # TODO: remove deprecated @beacon_path_params
          |> Component.assign(:beacon_path_params, beacon_assigns.path_params)
          # TODO: remove deprecated @beacon_query_params
          |> Component.assign(:beacon_query_params, beacon_assigns.query_params)
          |> Component.assign(:beacon, beacon_assigns)
          |> Component.assign(:page_title, Beacon.Web.DataSource.page_title(site, page.id, live_data, :beacon))

        {:noreply, push_event(socket, "beacon:page-updated", %{meta_tags: Beacon.Web.DataSource.meta_tags(socket.assigns)})}
    end
  end

  @doc false
  def make_env(site) do
    imports = [
      Loader.Routes.module_name(site),
      Loader.Components.module_name(site)
    ]

    Enum.reduce(imports, __ENV__, fn module, env ->
      with true <- :erlang.module_loaded(module),
           {:ok, env} <- define_import(env, module) do
        env
      else
        {:error, error} -> raise Beacon.LoaderError, "failed to import #{module}: #{error}"
        _ -> env
      end
    end)
  end

  # TODO: remove after requiring Elixir 1.17+
  if Version.match?(System.version(), ">= 1.17.0") do
    defp define_import(env, module) do
      meta = []
      Macro.Env.define_import(env, meta, module)
    end
  else
    defp define_import(env, module) do
      meta = []
      opts = []
      {functions, macros} = :elixir_import.import(meta, module, opts, env)
      env = %{env | functions: functions, macros: macros, requires: [module | env.requires]}
      {:ok, env}
    end
  end
end
