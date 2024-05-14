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

  @doc false
  def update_private(%{assigns: %{beacon: _beacon}} = socket, key, value) do
    Phoenix.Component.update(socket, :beacon, fn beacon ->
      put_in(beacon, [Access.key(:private), Access.key(key)], value)
    end)
  end
end
