defmodule Beacon.Collection.FieldValidator do
  @moduledoc """
  Validates a page's `fields` JSONB against its collection's `field_definitions`.
  """

  @doc """
  Validates the `:fields` value in a changeset against the given field definitions.

  Checks required fields and basic type coercion. Adds errors on the `:fields` key.
  """
  @spec validate(Ecto.Changeset.t(), [map()]) :: Ecto.Changeset.t()
  def validate(changeset, []), do: changeset

  def validate(changeset, field_definitions) when is_list(field_definitions) do
    fields = Ecto.Changeset.get_field(changeset, :fields) || %{}

    Enum.reduce(field_definitions, changeset, fn definition, cs ->
      name = definition["name"]
      type = definition["type"]
      required = definition["required"] == true
      value = fields[name]

      cond do
        required and (is_nil(value) or value == "") ->
          Ecto.Changeset.add_error(cs, :fields, "#{name} is required")

        not is_nil(value) and value != "" and not valid_type?(value, type) ->
          Ecto.Changeset.add_error(cs, :fields, "#{name} must be a valid #{type}")

        true ->
          cs
      end
    end)
  end

  defp valid_type?(value, "string"), do: is_binary(value)
  defp valid_type?(value, "text"), do: is_binary(value)
  defp valid_type?(value, "url"), do: is_binary(value)
  defp valid_type?(value, "integer"), do: is_integer(value)
  defp valid_type?(value, "float"), do: is_float(value) or is_integer(value)
  defp valid_type?(value, "boolean"), do: is_boolean(value)
  defp valid_type?(value, "datetime"), do: is_binary(value)
  defp valid_type?(value, "date"), do: is_binary(value)
  defp valid_type?(value, "select"), do: is_binary(value)
  defp valid_type?(value, "list"), do: is_list(value)
  defp valid_type?(value, "reference"), do: is_binary(value)
  defp valid_type?(_, _), do: true
end
