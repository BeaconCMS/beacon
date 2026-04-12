defmodule Beacon.GraphQL.Introspection do
  @moduledoc false

  alias Beacon.Content
  alias Beacon.Content.GraphQLEndpoint
  alias Beacon.GraphQL.Client

  @introspection_query """
  query IntrospectionQuery {
    __schema {
      queryType { name }
      mutationType { name }
      types {
        kind
        name
        description
        fields(includeDeprecated: true) {
          name
          description
          args {
            name
            description
            type { ...TypeRef }
            defaultValue
          }
          type { ...TypeRef }
          isDeprecated
          deprecationReason
        }
        inputFields {
          name
          description
          type { ...TypeRef }
          defaultValue
        }
        enumValues(includeDeprecated: true) {
          name
          description
          isDeprecated
          deprecationReason
        }
        possibleTypes { ...TypeRef }
      }
    }
  }

  fragment TypeRef on __Type {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
          }
        }
      }
    }
  }
  """

  @doc """
  Introspect a GraphQL endpoint and store the normalized schema.
  """
  @spec introspect(atom(), binary()) :: {:ok, map()} | {:error, term()}
  def introspect(site, endpoint_name) do
    case Content.get_graphql_endpoint_by(site, name: endpoint_name) do
      nil ->
        {:error, {:endpoint_not_found, endpoint_name}}

      endpoint ->
        case Client.execute_raw(endpoint, @introspection_query, %{}, timeout: 30_000) do
          {:ok, %{"__schema" => schema}} ->
            normalized = normalize_schema(schema)

            {:ok, _updated} =
              Content.update_graphql_endpoint(endpoint, %{introspected_schema: normalized})

            Beacon.GraphQL.EndpointCache.invalidate(site, endpoint_name)
            {:ok, normalized}

          {:error, reason} ->
            {:error, {:introspection_failed, reason}}

          other ->
            {:error, {:unexpected_response, other}}
        end
    end
  end

  @doc """
  Store an SDL schema string and parse it into the normalized format.
  This is the fallback when introspection is disabled.

  The SDL is parsed into queries, mutations, and types using regex-based
  extraction (no GraphQL parser dependency needed).
  """
  @spec store_sdl(atom(), binary(), binary()) :: {:ok, GraphQLEndpoint.t()} | {:error, term()}
  def store_sdl(site, endpoint_name, sdl_string) do
    case Content.get_graphql_endpoint_by(site, name: endpoint_name) do
      nil ->
        {:error, {:endpoint_not_found, endpoint_name}}

      endpoint ->
        parsed = parse_sdl(sdl_string)

        Content.update_graphql_endpoint(endpoint, %{
          sdl_schema: sdl_string,
          introspected_schema: parsed
        })
    end
  end

  @doc """
  Parse an SDL string into the normalized schema format.
  Uses regex-based extraction for basic SDL support without a full parser.
  """
  @spec parse_sdl(binary()) :: map()
  def parse_sdl(sdl_string) do
    types = extract_sdl_types(sdl_string)
    query_type = Enum.find(types, &(&1["name"] == "Query"))
    mutation_type = Enum.find(types, &(&1["name"] == "Mutation"))

    %{
      "queries" => if(query_type, do: query_type["fields"], else: []),
      "mutations" => if(mutation_type, do: mutation_type["fields"], else: []),
      "types" => Enum.reject(types, &(&1["name"] in ["Query", "Mutation", "Subscription"])),
      "query_type_name" => "Query",
      "mutation_type_name" => "Mutation"
    }
  end

  defp extract_sdl_types(sdl) do
    # Match type blocks: "type TypeName { ... }"
    Regex.scan(~r/type\s+(\w+)\s*\{([^}]*)\}/s, sdl)
    |> Enum.map(fn [_, name, body] ->
      fields = extract_sdl_fields(body)
      %{"kind" => "OBJECT", "name" => name, "fields" => fields, "inputFields" => [], "enumValues" => [], "description" => nil}
    end)
  end

  defp extract_sdl_fields(body) do
    # Match field definitions: "fieldName(arg: Type, arg2: Type!): ReturnType"
    Regex.scan(~r/(\w+)(\([^)]*\))?\s*:\s*([^\n,]+)/, body)
    |> Enum.map(fn
      [_, name, args_str, return_type] ->
        args = extract_sdl_args(args_str)
        %{
          "name" => name,
          "description" => nil,
          "type" => parse_sdl_type_ref(String.trim(return_type)),
          "args" => args,
          "isDeprecated" => false,
          "deprecationReason" => nil
        }

      [_, name, return_type] ->
        %{
          "name" => name,
          "description" => nil,
          "type" => parse_sdl_type_ref(String.trim(return_type)),
          "args" => [],
          "isDeprecated" => false,
          "deprecationReason" => nil
        }
    end)
  end

  defp extract_sdl_args(""), do: []
  defp extract_sdl_args(nil), do: []
  defp extract_sdl_args(args_str) do
    # Strip parens
    inner = String.trim_leading(args_str, "(") |> String.trim_trailing(")")

    Regex.scan(~r/(\w+)\s*:\s*([^,\)]+)/, inner)
    |> Enum.map(fn [_, name, type_str] ->
      %{
        "name" => name,
        "description" => nil,
        "type" => parse_sdl_type_ref(String.trim(type_str)),
        "defaultValue" => nil
      }
    end)
  end

  defp parse_sdl_type_ref(type_str) do
    cond do
      String.ends_with?(type_str, "!") ->
        inner = String.trim_trailing(type_str, "!")
        %{"kind" => "NON_NULL", "name" => nil, "ofType" => parse_sdl_type_ref(inner)}

      String.starts_with?(type_str, "[") and String.ends_with?(type_str, "]") ->
        inner = type_str |> String.trim_leading("[") |> String.trim_trailing("]")
        %{"kind" => "LIST", "name" => nil, "ofType" => parse_sdl_type_ref(inner)}

      type_str in ~w(String Int Float Boolean ID) ->
        %{"kind" => "SCALAR", "name" => type_str, "ofType" => nil}

      true ->
        %{"kind" => "OBJECT", "name" => type_str, "ofType" => nil}
    end
  end

  @doc """
  List available queries from the stored schema.
  """
  @spec list_queries(atom(), binary()) :: [map()]
  def list_queries(site, endpoint_name) do
    case get_schema(site, endpoint_name) do
      {:ok, schema} -> Map.get(schema, "queries", [])
      :error -> []
    end
  end

  @doc """
  List available mutations from the stored schema.
  """
  @spec list_mutations(atom(), binary()) :: [map()]
  def list_mutations(site, endpoint_name) do
    case get_schema(site, endpoint_name) do
      {:ok, schema} -> Map.get(schema, "mutations", [])
      :error -> []
    end
  end

  @doc """
  Get all type definitions from the stored schema.
  """
  @spec list_types(atom(), binary()) :: [map()]
  def list_types(site, endpoint_name) do
    case get_schema(site, endpoint_name) do
      {:ok, schema} -> Map.get(schema, "types", [])
      :error -> []
    end
  end

  @doc """
  Get argument information for a specific operation.
  """
  @spec get_operation_args(atom(), binary(), binary()) :: [map()]
  def get_operation_args(site, endpoint_name, operation_name) do
    queries = list_queries(site, endpoint_name)
    mutations = list_mutations(site, endpoint_name)

    case Enum.find(queries ++ mutations, &(&1["name"] == operation_name)) do
      nil -> []
      operation -> Map.get(operation, "args", [])
    end
  end

  defp get_schema(site, endpoint_name) do
    case Beacon.GraphQL.EndpointCache.get_endpoint(site, endpoint_name) do
      {:ok, %{introspected_schema: schema}} when is_map(schema) -> {:ok, schema}
      _ -> :error
    end
  end

  defp normalize_schema(schema) do
    query_type_name = get_in(schema, ["queryType", "name"]) || "Query"
    mutation_type_name = get_in(schema, ["mutationType", "name"]) || "Mutation"

    types = schema["types"] || []

    # Filter out introspection types (those starting with __)
    user_types =
      types
      |> Enum.reject(&String.starts_with?(&1["name"] || "", "__"))
      |> Enum.map(&normalize_type/1)

    # Extract queries (fields of the Query type)
    queries =
      types
      |> Enum.find(&(&1["name"] == query_type_name))
      |> case do
        nil -> []
        query_type -> Enum.map(query_type["fields"] || [], &normalize_field/1)
      end

    # Extract mutations (fields of the Mutation type)
    mutations =
      types
      |> Enum.find(&(&1["name"] == mutation_type_name))
      |> case do
        nil -> []
        mutation_type -> Enum.map(mutation_type["fields"] || [], &normalize_field/1)
      end

    %{
      "queries" => queries,
      "mutations" => mutations,
      "types" => user_types,
      "query_type_name" => query_type_name,
      "mutation_type_name" => mutation_type_name
    }
  end

  defp normalize_type(type) do
    %{
      "kind" => type["kind"],
      "name" => type["name"],
      "description" => type["description"],
      "fields" => Enum.map(type["fields"] || [], &normalize_field/1),
      "inputFields" => Enum.map(type["inputFields"] || [], &normalize_input_field/1),
      "enumValues" => Enum.map(type["enumValues"] || [], &normalize_enum_value/1)
    }
  end

  defp normalize_field(field) do
    %{
      "name" => field["name"],
      "description" => field["description"],
      "type" => field["type"],
      "args" => Enum.map(field["args"] || [], &normalize_input_field/1),
      "isDeprecated" => field["isDeprecated"] || false,
      "deprecationReason" => field["deprecationReason"]
    }
  end

  defp normalize_input_field(field) do
    %{
      "name" => field["name"],
      "description" => field["description"],
      "type" => field["type"],
      "defaultValue" => field["defaultValue"]
    }
  end

  defp normalize_enum_value(value) do
    %{
      "name" => value["name"],
      "description" => value["description"],
      "isDeprecated" => value["isDeprecated"] || false
    }
  end
end
