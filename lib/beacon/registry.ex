defmodule Beacon.Registry do
  def child_spec(_arg) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def via(key), do: {:via, Registry, {__MODULE__, key}}
  def via(key, value), do: {:via, Registry, {__MODULE__, key, value}}

  def config!(site) do
    case lookup({:site, site}) do
      {_pid, config} ->
        config

      _ ->
        raise RuntimeError, """
        Site #{inspect(site)} was not found. Make sure it's configured and started,
        see `Beacon.start_link/1` for more info.
        """
    end
  end

  def registered_sites do
    match = {{:site, :"$1"}, :_, :_}
    guards = []
    body = [:"$1"]

    Registry.select(__MODULE__, [{match, guards, body}])
  end

  defp lookup(site) do
    __MODULE__
    |> Registry.lookup(site)
    |> List.first()
  end
end
