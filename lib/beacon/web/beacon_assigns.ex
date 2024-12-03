defmodule Beacon.Web.BeaconAssigns do
  @moduledoc """
  Read-only container of Beacon assigns related to the current page.

  Available as `@beacon`

  This data can be accessed in page templates, event handlers, and other parts of your site
  to read information about the current page as the current site, path and query params,
  path and title.

  More fields may be added in the future.

  ## Examples

  In a template:

      <h1><%= @beacon.page.title %></h1>

  In a event handler:

      pages = Beacon.Content.list_published_pages(@beacon.site)

  """

  @derive {Inspect, only: [:site, :path_params, :query_params, :page]}

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path_params: %{String.t() => term()},
          query_params: %{String.t() => term()},
          page: %{path: String.t(), title: String.t()},
          private: map()
        }

  defstruct site: nil,
            path_params: %{},
            query_params: %{},
            page: %{path: nil, title: nil},
            private: %{
              page_module: nil,
              components_module: nil,
              info_handlers_module: nil,
              event_handlers_module: nil,
              live_data_keys: [],
              live_path: [],
              variant_roll: nil
            }

  @doc false
  def new(site) when is_atom(site) do
    components_module = Beacon.Loader.Components.module_name(site)
    %__MODULE__{site: site, private: %{components_module: components_module}}
  end

  @doc false
  def new(site, %Beacon.Content.Page{} = page, variant_roll) do
    components_module = Beacon.Loader.Components.module_name(site)
    page_module = Beacon.Loader.Page.module_name(site, page.id)

    %__MODULE__{
      site: site,
      private: %{
        components_module: components_module,
        page_module: page_module,
        variant_roll: variant_roll
      }
    }
  end

  @doc false
  def new(site, %Beacon.Content.Page{} = page, live_data, path_info, query_params, source, variant_roll \\ nil)
      when is_atom(site) and is_map(live_data) and is_list(path_info) and is_map(query_params) and source in [:beacon, :admin] do
    %{site: ^site} = page
    page_module = Beacon.Loader.Page.module_name(site, page.id)
    live_data = Beacon.Web.DataSource.live_data(site, path_info, Map.drop(query_params, ["path"]))
    path_params = Beacon.Router.path_params(page.path, path_info)
    page_title = Beacon.Web.DataSource.page_title(site, page.id, live_data, source)
    components_module = Beacon.Loader.Components.module_name(site)
    info_handlers_module = Beacon.Loader.InfoHandlers.module_name(site)
    event_handlers_module = Beacon.Loader.EventHandlers.module_name(site)

    %__MODULE__{
      site: page.site,
      path_params: path_params,
      query_params: query_params,
      page: %{path: page.path, title: page_title},
      private: %{
        page_module: page_module,
        components_module: components_module,
        info_handlers_module: info_handlers_module,
        event_handlers_module: event_handlers_module,
        live_data_keys: Map.keys(live_data),
        live_path: path_info,
        variant_roll: variant_roll
      }
    }
  end

  @doc false
  def update(_socket_or_assigns, _key, _value)

  def update(%{assigns: %{beacon: _beacon}} = socket, key, value) do
    do_update_socket_or_assigns(socket, key, value)
  end

  def update(%{beacon: _beacon} = assigns, key, value) do
    do_update_socket_or_assigns(assigns, key, value)
  end

  def update(_socket_or_assigns, _key, _value), do: raise("expected :beacon assign in socket but none found")

  defp do_update_socket_or_assigns(socket_or_assigns, key, value) do
    Phoenix.Component.update(socket_or_assigns, :beacon, fn beacon ->
      Map.put(beacon, key, value)
    end)
  end
end
