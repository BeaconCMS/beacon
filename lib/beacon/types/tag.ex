defmodule Beacon.Types.Tag do
  use Ecto.Type
  def type, do: :map

  def cast(tags), do: {:ok, tags}

  # convert the map to list of lists of tuples, then order correctly
  def load(tags) when is_list(tags) do
    {:ok, Enum.map(tags, fn tags -> Map.to_list(tags) end) |> order_name_and_property_first}
  end

  # ordering of attributes to account for unguaranteed ordering of maps
  defp order_name_and_property_first(tags) do
    Enum.map(tags, 
      fn tag ->
        Enum.sort_by(tag, 
          fn kv = {"name", _} -> 
            kv 
          kv = {"property", _} ->
            kv 
          kv = {"content", _} -> 
            kv
          _ ->
          end, &==/2)
    end)
  end

  def dump(tags), do: {:ok, tags}
  def dump(_), do: :error
end