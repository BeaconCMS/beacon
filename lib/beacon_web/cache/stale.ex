# Copied and modified from https://github.com/hexpm/hexpm/blob/d5b4e3864e219dd8b2cca34570dbe60257bcc547/lib/hexpm_web/stale.ex
# Originally licensed under Apache 2.0 available at https://www.apache.org/licenses/LICENSE-2.0

defprotocol BeaconWeb.Cache.Stale do
  @moduledoc false

  def etag(schema)
  def last_modified(schema)
end

defimpl BeaconWeb.Cache.Stale, for: Atom do
  def etag(nil), do: nil

  # This is not a good solution because we don't know when a missing
  # association was modified but this is the best we have for now
  def last_modified(nil), do: ~N[0000-01-01 00:00:00]
end

defimpl BeaconWeb.Cache.Stale, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    etag_keys = Keyword.get(opts, :etag, [:__struct__, :id, :updated_at])
    last_modified_key = Keyword.get(opts, :last_modified, :updated_at)
    assocs = Keyword.get(opts, :assocs, [])

    quote do
      defimpl BeaconWeb.Cache.Stale, for: unquote(module) do
        alias BeaconWeb.Cache.Stale
        alias BeaconWeb.Cache.Stale.Any

        def etag(schema) do
          assocs = unquote(assocs)
          etag_keys = unquote(etag_keys)
          [Map.take(schema, etag_keys), Any.recurse_fields(schema, assocs, &Stale.etag/1)]
        end

        def last_modified(schema) do
          assocs = unquote(assocs)
          last_modified_key = unquote(last_modified_key)
          last_modified = fetch_last_modified(schema, last_modified_key)
          [last_modified, Any.recurse_fields(schema, assocs, &Stale.last_modified/1)]
        end

        defp fetch_last_modified(_schema, nil), do: ~N[0000-01-01 00:00:00]
        defp fetch_last_modified(schema, key), do: Map.fetch!(schema, key)
      end
    end
  end

  def etag(_), do: raise("not implemented")
  def last_modified(_), do: raise("not implemented")

  def recurse_fields(schema, keys, fun) do
    Enum.map(keys, fn key ->
      Map.fetch!(schema, key)
      |> recurse_field(fun)
    end)
  end

  defp recurse_field(%Ecto.Association.NotLoaded{}, _fun), do: []
  defp recurse_field(schemas, fun) when is_list(schemas), do: Enum.map(schemas, fun)
  defp recurse_field(schema, fun), do: fun.(schema)
end
