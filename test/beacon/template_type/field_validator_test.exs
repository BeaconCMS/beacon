defmodule Beacon.TemplateType.FieldValidatorTest do
  use ExUnit.Case, async: true

  alias Beacon.TemplateType.FieldValidator

  defp changeset_with_fields(fields) do
    types = %{fields: :map}
    {%{fields: fields}, types}
    |> Ecto.Changeset.cast(%{}, [])
    |> Ecto.Changeset.put_change(:fields, fields)
  end

  test "passes with no field definitions" do
    cs = changeset_with_fields(%{})
    result = FieldValidator.validate(cs, [])
    assert result.valid?
  end

  test "passes when all required fields are present" do
    cs = changeset_with_fields(%{"name" => "Jane", "age" => 30})
    definitions = [
      %{"name" => "name", "type" => "string", "required" => true},
      %{"name" => "age", "type" => "integer", "required" => true}
    ]

    result = FieldValidator.validate(cs, definitions)
    assert result.valid?
  end

  test "fails when required field is missing" do
    cs = changeset_with_fields(%{})
    definitions = [%{"name" => "title", "type" => "string", "required" => true}]

    result = FieldValidator.validate(cs, definitions)
    refute result.valid?
    assert Keyword.has_key?(result.errors, :fields)
  end

  test "fails when required field is empty string" do
    cs = changeset_with_fields(%{"title" => ""})
    definitions = [%{"name" => "title", "type" => "string", "required" => true}]

    result = FieldValidator.validate(cs, definitions)
    refute result.valid?
  end

  test "passes with optional field missing" do
    cs = changeset_with_fields(%{})
    definitions = [%{"name" => "bio", "type" => "text", "required" => false}]

    result = FieldValidator.validate(cs, definitions)
    assert result.valid?
  end

  test "validates string type" do
    cs = changeset_with_fields(%{"name" => 123})
    definitions = [%{"name" => "name", "type" => "string"}]

    result = FieldValidator.validate(cs, definitions)
    refute result.valid?
  end

  test "validates integer type" do
    cs = changeset_with_fields(%{"count" => "not a number"})
    definitions = [%{"name" => "count", "type" => "integer"}]

    result = FieldValidator.validate(cs, definitions)
    refute result.valid?
  end

  test "validates boolean type" do
    cs = changeset_with_fields(%{"active" => true})
    definitions = [%{"name" => "active", "type" => "boolean"}]

    result = FieldValidator.validate(cs, definitions)
    assert result.valid?
  end

  test "validates list type" do
    cs = changeset_with_fields(%{"tags" => ["a", "b"]})
    definitions = [%{"name" => "tags", "type" => "list"}]

    result = FieldValidator.validate(cs, definitions)
    assert result.valid?
  end
end
