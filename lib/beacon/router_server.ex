defmodule Beacon.RouterServer do
  @moduledoc false
  # credo:disable-for-this-file

  use GenServer
  require Logger
  alias Beacon.Content
  alias Beacon.PubSub

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  def table_name(site) do
    String.to_atom("beacon_router_#{site}")
  end

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def init(config) do
    # We store routes by order and length so the most visited pages will likely be in the first rows
    :ets.new(table_name(config.site), [:ordered_set, :named_table, :public, read_concurrency: true])

    if config.mode == :live do
      {:ok, config, {:continue, :async_init}}
    else
      {:ok, config}
    end
  end

  def terminate(_reason, config) do
    :ets.delete(table_name(config.site))
    :ok
  end

  # Client

  def lookup_page(site, path_info) when is_atom(site) and is_list(path_info) do
    with {_path, page_id} <- lookup_path(site, path_info) do
      page_module = Beacon.Loader.fetch_page_module(site, page_id)
      Beacon.apply_mfa(site, page_module, :page, [])
    else
      _ -> nil
    end
  end

  def lookup_page!(site, path_info) when is_atom(site) and is_list(path_info) do
    case lookup_page(site, path_info) do
      nil ->
        raise Beacon.Web.NotFoundError, """
        no page found for site #{site} and path #{inspect(path_info)}

        Make sure a page was created for that path.
        """

      page ->
        page
    end
  end

  @doc """
  Inserts or replace a page in the router.
  """
  def add_page(site, id, path) when is_atom(site) and is_binary(id) and is_binary(path) do
    GenServer.call(name(site), {:add_page, id, path})
  end

  def del_page(site, path) when is_atom(site) and is_binary(path) do
    GenServer.call(name(site), {:del_page, path})
  end

  def del_pages(site) when is_atom(site) do
    GenServer.call(name(site), :del_pages)
  end

  def lookup_path(site, path_info, limit \\ 10) when is_atom(site) and is_list(path_info) and is_integer(limit) do
    GenServer.call(name(site), {:lookup_path, path_info, limit})
  end

  def dump_pages(site) when is_atom(site) do
    GenServer.call(name(site), :dump_pages)
  end

  # Server

  def handle_continue(:async_init, config) do
    %{site: site} = config

    :ok = PubSub.subscribe_to_pages(site)

    for page <- Content.list_published_pages(site, per_page: :infinity) do
      do_add_page(page.site, page.id, page.path)
    end

    {:noreply, config}
  end

  def handle_call({:add_page, id, path}, _from, config) do
    %{site: site} = config
    {:reply, do_add_page(site, id, path), config}
  end

  def handle_call({:del_page, path}, _from, config) do
    :ets.delete(table_name(config.site), path)
    {:reply, :ok, config}
  end

  def handle_call(:del_pages, _from, config) do
    :ets.delete_all_objects(table_name(config.site))
    {:reply, :ok, config}
  end

  def handle_call({:lookup_path, path_info, limit}, _from, config) do
    lookup_table = table_name(config.site)
    route = do_lookup_path(lookup_table, path_info, limit)
    {:reply, route, config}
  end

  def handle_call(:dump_pages, _from, config) do
    pages = config.site |> table_name() |> :ets.match(:"$1") |> List.flatten()
    {:reply, pages, config}
  end

  # TODO: check page.site == config.site?
  defp do_add_page(site, id, path) do
    true = :ets.insert(table_name(site), {path, id})
    :ok
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
  defp do_lookup_path(table, path_info, limit) do
    if route = match_static_routes(table, path_info) do
      route
    else
      match_dynamic_routes(:ets.match(table, :"$1", limit), path_info)
    end
  end

  defp match_static_routes(table, path_info) do
    path =
      case Enum.join(path_info, "/") do
        "" -> "/"
        path -> path
      end

    match = {path, :_}
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
      Enum.find(routes, fn [{page_path, _id}] ->
        match_path?(page_path, path_info)
      end)

    case route do
      [route] -> route
      _ -> nil
    end
  end

  defp match_dynamic_routes({routes, cont}, path_info) do
    route =
      Enum.find(routes, fn [{page_path, _id}] ->
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
          segment == matching_segment && position + 1 == page_path_length -> {:cont, {position + 1, true}}
          segment == matching_segment -> {:cont, {position + 1, false}}
          :no_match -> {:halt, {position, false}}
        end
      end)

    match?
  end

  def handle_info({:page_loaded, %{site: site, id: id, path: path}}, config) do
    :ok = do_add_page(site, id, path)
    {:noreply, config}
  end

  def handle_info(_msg, config) do
    {:noreply, config}
  end
end
