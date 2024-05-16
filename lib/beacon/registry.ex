defmodule Beacon.Registry do
  @moduledoc """
  Site process storage.

  Each site `Beacon.Config` is stored in this registry.
  """

  @doc false
  def child_spec(_arg) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  @doc false
  def via(key), do: {:via, Registry, {__MODULE__, key}}

  @doc false
  def via(key, value), do: {:via, Registry, {__MODULE__, key, value}}

  @doc """
  Return a list of all running sites in the current node.
  """
  @spec running_sites() :: [Beacon.Types.Site.t()]
  def running_sites do
    match = {{:site, :"$1"}, :_, :_}
    guards = []
    body = [:"$1"]

    Registry.select(__MODULE__, [{match, guards, body}])
  end

  @doc false
  def update_config(site, fun) when is_atom(site) and is_function(fun, 1) do
    result =
      Registry.update_value(__MODULE__, {:site, site}, fn config ->
        fun.(config)
      end)

    case result do
      {new_value, _old_value} -> new_value
      error -> error
    end
  end

  @doc false
  def lookup(key) do
    __MODULE__
    |> Registry.lookup(key)
    |> List.first()
  end
end
