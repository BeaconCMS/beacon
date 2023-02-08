defmodule Beacon.Types.Tag do
  use Ecto.Type
  def type, do: :map

  def cast(tags), do: {:ok, tags}

  # convert the map to list of lists of tuples, then order correctly
  def load(tags) when is_list(tags) do
    {:ok, Enum.map(tags, fn tags -> Map.to_list(tags) end) |> order_attributes()}
  end

  # ordering of attributes to account for unguaranteed ordering of maps;
  # intended to work with theoretical meta tag with 3+ attributes;
  # TODO? make single generic function with Beacon.order_attributes taking list of attribute keys
  def order_attributes(tags) do
    Enum.map(
      tags,
      fn tag ->
        Enum.sort_by(
          tag,
          fn
            kv = {"name", _} ->
              kv

            kv = {"property", _} ->
              kv

            kv = {"content", _} ->
              kv

            _ ->
              nil
          end,
          # swap attributes
          fn
            nil, kv ->
              false

            {k1, _}, {k2, _} when k1 == "content" and (k2 == "name" or k2 == "property") ->
              false

            # don't swap
            kv, nil ->
              true

            _, _ ->
              true
          end
        )
      end
    )
  end

  def dump(tags), do: {:ok, tags}
  # def dump(_), do: :error
end
