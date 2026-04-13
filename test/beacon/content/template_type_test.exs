defmodule Beacon.Content.TemplateTypeTest do
  use ExUnit.Case, async: true

  alias Beacon.Content.TemplateType

  describe "changeset/2" do
    test "valid with name and slug" do
      attrs = %{name: "Blog Post", slug: "blog-post"}
      cs = TemplateType.changeset(%TemplateType{}, attrs)
      assert cs.valid?
    end

    test "requires name" do
      cs = TemplateType.changeset(%TemplateType{}, %{slug: "test"})
      refute cs.valid?
    end

    test "requires slug" do
      cs = TemplateType.changeset(%TemplateType{}, %{name: "Test"})
      refute cs.valid?
    end

    test "validates slug format — lowercase with hyphens" do
      cs = TemplateType.changeset(%TemplateType{}, %{name: "Test", slug: "Valid-Slug"})
      refute cs.valid?

      cs = TemplateType.changeset(%TemplateType{}, %{name: "Test", slug: "valid-slug"})
      assert cs.valid?
    end

    test "validates slug format — no spaces" do
      cs = TemplateType.changeset(%TemplateType{}, %{name: "Test", slug: "has space"})
      refute cs.valid?
    end

    test "validates field_definitions — rejects non-maps" do
      cs = TemplateType.changeset(%TemplateType{}, %{name: "T", slug: "t", field_definitions: ["not a map"]})
      refute cs.valid?
    end

    test "validates field_definitions — requires name on each item" do
      cs = TemplateType.changeset(%TemplateType{}, %{name: "T", slug: "t", field_definitions: [%{"type" => "string"}]})
      refute cs.valid?
    end

    test "validates field_definitions — requires valid type" do
      cs = TemplateType.changeset(%TemplateType{}, %{name: "T", slug: "t", field_definitions: [%{"name" => "x", "type" => "invalid"}]})
      refute cs.valid?
    end

    test "validates field_definitions — rejects duplicate names" do
      defs = [%{"name" => "title", "type" => "string"}, %{"name" => "title", "type" => "text"}]
      cs = TemplateType.changeset(%TemplateType{}, %{name: "T", slug: "t", field_definitions: defs})
      refute cs.valid?
    end

    test "valid field_definitions with proper structure" do
      defs = [
        %{"name" => "author", "type" => "string", "required" => true, "label" => "Author"},
        %{"name" => "date", "type" => "datetime"}
      ]
      cs = TemplateType.changeset(%TemplateType{}, %{name: "Blog", slug: "blog", field_definitions: defs})
      assert cs.valid?
    end

    test "site can be nil for global types" do
      cs = TemplateType.changeset(%TemplateType{}, %{name: "Global", slug: "global", site: nil})
      assert cs.valid?
    end
  end
end
