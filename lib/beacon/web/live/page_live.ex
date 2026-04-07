defmodule Beacon.Web.PageLive do
  @moduledoc false

  use Beacon.Web, :live_view
  require Logger
  import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3], warn: false
  import Beacon.Web, only: [assign: 2, assign: 3, assign_new: 3], warn: false
  alias Phoenix.Component

  def mount(:not_mounted_at_router, _params, socket) do
    {:ok, socket}
  end

  def mount(params, session, socket) do
    %{"path" => path} = params
    %{"beacon_site" => site} = session
    config = Beacon.Config.fetch!(site)

    if config.mode == :live and connected?(socket) do
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

    path_str = "/" <> Enum.join(path, "/")
    {:ok, assigns} = Beacon.RuntimeRenderer.mount_assigns(site, path_str, variant_roll: variant_roll)
    socket = Component.assign(socket, assigns)
    {:ok, socket, layout: {Beacon.Web.Layouts, :dynamic}}
  end

  def render(assigns) do
    %{beacon: %{site: site, private: %{page_id: page_id}}} = assigns
    {:ok, rendered} = Beacon.RuntimeRenderer.render_page(site, page_id, assigns)
    rendered
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
    %{beacon: %{site: site, private: %{page_id: page_id}}} = socket.assigns

    case Beacon.RuntimeRenderer.handle_site_info(site, msg, socket) do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      {:error, {:no_handler, _}} ->
        Logger.warning("[Beacon] No info handler for message #{inspect(msg)} on page #{page_id}")
        {:noreply, socket}

      other ->
        raise Beacon.Web.ServerError,
              "handle_info expected {:noreply, socket}, got #{inspect(other)}"
    end
  end

  def handle_event(event_name, event_params, socket) do
    %{beacon: %{site: site}} = socket.assigns

    case Beacon.RuntimeRenderer.handle_site_event(site, event_name, event_params, socket) do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      {:error, {:no_handler, _}} ->
        {:noreply, socket}

      other ->
        raise Beacon.Web.ServerError,
              "handle_event expected {:noreply, socket}, got #{inspect(other)}"
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
        path_str = "/" <> Enum.join(path_info, "/")

        if socket.assigns.beacon.site != site && Beacon.Config.fetch!(site).mode == :live do
          Beacon.PubSub.unsubscribe_to_page(socket.assigns.beacon.site, path_info)
          Beacon.PubSub.subscribe_to_page(site, path_info)
        end

        {:ok, params_assigns} = Beacon.RuntimeRenderer.handle_params_assigns(site, path_str, params)

        socket =
          socket
          |> Component.assign(params_assigns)
          |> Component.assign(:page_title, params_assigns.beacon.page.title)

        {:noreply, socket}
    end
  end

  @doc false
  def make_env(_site) do
    __ENV__
  end

end
