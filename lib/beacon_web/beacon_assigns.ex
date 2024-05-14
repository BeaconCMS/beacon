defmodule BeaconWeb.BeaconAssigns do
  @moduledoc """
  Container of Beacon assigns related to the current page.

  These assigns can be used in page template or Elixir code, for example in in an event handler,
  and  they are made available as `@beacon`:

  ## Example

      <h1><%= @beacon.site %></h1>

  """

  @derive {Inspect, only: [:site, :path_params, :query_params, :page]}

  defstruct site: nil,
            path_params: %{},
            query_params: %{},
            page: %{title: nil},
            private: %{
              live_data_keys: [],
              live_path: [],
              layout_id: nil,
              page_id: nil,
              page_updated_at: nil,
              page_module: nil,
              components_module: nil
            }

  @doc false
  def build(site) when is_atom(site), do: %__MODULE__{site: site}

  def build(beacon_assigns = %__MODULE__{}, path_info, query_params) when is_list(path_info) and is_map(query_params) do
    site = beacon_assigns.site
    %{site: ^site} = page = Beacon.RouterServer.lookup_page!(site, path_info)
    components_module = Beacon.Loader.Components.module_name(site)
    page_module = Beacon.Loader.Page.module_name(site, page.id)
    live_data = BeaconWeb.DataSource.live_data(site, path_info, Map.drop(query_params, ["path"]))
    page_title = BeaconWeb.DataSource.page_title(site, page.id, live_data)

    %{
      beacon_assigns
      | query_params: query_params,
        page: %{path: page.path, title: page_title},
        private: %{
          live_data_keys: Map.keys(live_data),
          live_path: path_info,
          layout_id: page.layout_id,
          page_id: page.id,
          page_updated_at: DateTime.utc_now(),
          page_module: page_module,
          components_module: components_module
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
