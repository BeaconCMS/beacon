defmodule Beacon.TemplateType.JsonLdResolverTest do
  use ExUnit.Case, async: true

  alias Beacon.TemplateType.JsonLdResolver

  @config %{site_name: "Test Site", site: :test_site}

  test "returns nil for empty mapping" do
    assert JsonLdResolver.resolve(%{}, %{}, %{}, @config) == nil
  end

  test "resolves field references from page fields" do
    mapping = %{"@type" => "Article", "headline" => "{fields.title_field}"}
    fields = %{"title_field" => "My Great Article"}
    manifest = %{}

    result = JsonLdResolver.resolve(mapping, fields, manifest, @config)

    assert result["@type"] == "Article"
    assert result["headline"] == "My Great Article"
  end

  test "resolves manifest references" do
    mapping = %{"headline" => "{title}", "url" => "{path}"}
    manifest = %{title: "Page Title", path: "/about"}

    result = JsonLdResolver.resolve(mapping, %{}, manifest, @config)

    assert result["headline"] == "Page Title"
    assert result["url"] == "/about"
  end

  test "resolves config references" do
    mapping = %{"publisher" => %{"name" => "{site_name}"}}

    result = JsonLdResolver.resolve(mapping, %{}, %{}, @config)

    assert result["publisher"]["name"] == "Test Site"
  end

  test "handles nested maps" do
    mapping = %{
      "@type" => "Article",
      "author" => %{
        "@type" => "Person",
        "name" => "{fields.author_name}"
      }
    }
    fields = %{"author_name" => "Jane Doe"}

    result = JsonLdResolver.resolve(mapping, fields, %{}, @config)

    assert result["author"]["@type"] == "Person"
    assert result["author"]["name"] == "Jane Doe"
  end

  test "handles arrays in mapping" do
    mapping = %{"@type" => "FAQPage", "items" => [%{"q" => "{fields.q1}"}]}
    fields = %{"q1" => "What is this?"}

    result = JsonLdResolver.resolve(mapping, fields, %{}, @config)

    assert hd(result["items"])["q"] == "What is this?"
  end

  test "unresolved references become empty strings" do
    mapping = %{"title" => "{fields.nonexistent}"}

    result = JsonLdResolver.resolve(mapping, %{}, %{}, @config)

    assert result["title"] == ""
  end

  test "non-string values pass through unchanged" do
    mapping = %{"count" => 42, "active" => true}

    result = JsonLdResolver.resolve(mapping, %{}, %{}, @config)

    assert result["count"] == 42
    assert result["active"] == true
  end
end
