defmodule Beacon.GraphQL.TypeCoercion do
  @moduledoc false

  @doc """
  Coerce string values from path/query params to their expected GraphQL types
  based on introspected type information.

  Type info is the `type` field from introspection, a nested structure like:
  `%{"kind" => "NON_NULL", "ofType" => %{"kind" => "SCALAR", "name" => "Int"}}`
  """
  @spec coerce(binary() | nil, map()) :: term()
  def coerce(nil, _type_info), do: nil

  def coerce(value, %{"kind" => "NON_NULL", "ofType" => inner}) do
    coerce(value, inner)
  end

  def coerce(value, %{"kind" => "LIST", "ofType" => inner}) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&coerce(String.trim(&1), inner))
  end

  def coerce(value, %{"kind" => "LIST"}) when is_list(value), do: value

  def coerce(value, %{"kind" => "SCALAR", "name" => "Int"}) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  def coerce(value, %{"kind" => "SCALAR", "name" => "Float"}) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> value
    end
  end

  def coerce(value, %{"kind" => "SCALAR", "name" => "Boolean"}) when is_binary(value) do
    case String.downcase(value) do
      "true" -> true
      "1" -> true
      "false" -> false
      "0" -> false
      _ -> value
    end
  end

  def coerce(value, %{"kind" => "SCALAR", "name" => "ID"}) when is_binary(value), do: value
  def coerce(value, %{"kind" => "SCALAR", "name" => "String"}) when is_binary(value), do: value

  # Custom scalars and enums pass through as strings
  def coerce(value, %{"kind" => "SCALAR"}), do: value
  def coerce(value, %{"kind" => "ENUM"}), do: value

  # Already the right type (e.g., integer from a literal binding)
  def coerce(value, _type_info), do: value

  @doc """
  Unwrap NON_NULL and LIST wrappers to find the base type.
  """
  @spec base_type(map()) :: {atom(), binary()} | {:list, {atom(), binary()}}
  def base_type(%{"kind" => "NON_NULL", "ofType" => inner}), do: base_type(inner)
  def base_type(%{"kind" => "LIST", "ofType" => inner}), do: {:list, base_type(inner)}
  def base_type(%{"kind" => "SCALAR", "name" => name}), do: {:scalar, name}
  def base_type(%{"kind" => "ENUM", "name" => name}), do: {:enum, name}
  def base_type(%{"kind" => "INPUT_OBJECT", "name" => name}), do: {:input_object, name}
  def base_type(%{"kind" => "OBJECT", "name" => name}), do: {:object, name}
  def base_type(_), do: {:unknown, "Unknown"}

  @doc """
  Check if a type is required (wrapped in NON_NULL).
  """
  @spec required?(map()) :: boolean()
  def required?(%{"kind" => "NON_NULL"}), do: true
  def required?(_), do: false
end
