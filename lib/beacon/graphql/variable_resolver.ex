defmodule Beacon.GraphQL.VariableResolver do
  @moduledoc false

  @doc """
  Resolve variable bindings into concrete values.

  Variable bindings map GraphQL variable names to value sources:

      %{
        "slug" => %{"source" => "path_param", "key" => "slug"},
        "limit" => %{"source" => "literal", "value" => 10},
        "page" => %{"source" => "query_param", "key" => "page", "default" => "1"},
        "authorId" => %{"source" => "query_result", "from" => "get_author", "path" => "data.author.id"}
      }

  Returns a map of resolved variable name => value.
  """
  @spec resolve(map(), map(), map(), map()) :: map()
  def resolve(variable_bindings, path_params, query_params, prior_results \\ %{}) do
    Map.new(variable_bindings, fn {var_name, binding} ->
      {var_name, resolve_binding(binding, path_params, query_params, prior_results)}
    end)
  end

  defp resolve_binding(%{"source" => "path_param", "key" => key} = binding, path_params, _query_params, _prior) do
    case Map.get(path_params, key) do
      nil -> Map.get(binding, "default")
      value -> value
    end
  end

  defp resolve_binding(%{"source" => "query_param", "key" => key} = binding, _path_params, query_params, _prior) do
    case Map.get(query_params, key) do
      nil -> Map.get(binding, "default")
      value -> value
    end
  end

  defp resolve_binding(%{"source" => "literal", "value" => value}, _path_params, _query_params, _prior) do
    value
  end

  defp resolve_binding(%{"source" => "query_result", "from" => from, "path" => path}, _path_params, _query_params, prior_results) do
    case Map.get(prior_results, from) do
      nil ->
        nil

      result ->
        get_nested(result, String.split(path, "."))
    end
  end

  defp resolve_binding(%{"source" => "event_param", "key" => _key} = binding, _path_params, _query_params, _prior) do
    # Event params are resolved at action execution time, not query time.
    # Return the binding as-is so the action interpreter can resolve it.
    Map.get(binding, "default")
  end

  defp resolve_binding(_binding, _path_params, _query_params, _prior), do: nil

  defp get_nested(value, []), do: value
  defp get_nested(nil, _path), do: nil
  defp get_nested(value, [key | rest]) when is_map(value) do
    get_nested(Map.get(value, key), rest)
  end
  defp get_nested(_value, _path), do: nil
end
