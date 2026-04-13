defmodule Beacon.TemplateType.MetaTagResolverTest do
  use ExUnit.Case, async: true

  alias Beacon.TemplateType.MetaTagResolver

  @config %{site_name: "Test Site", site: :test_site}

  test "returns empty for nil mapping" do
    assert MetaTagResolver.resolve(nil, %{}, %{}, @config) == []
  end

  test "returns empty for empty list" do
    assert MetaTagResolver.resolve([], %{}, %{}, @config) == []
  end

  test "resolves field references in meta tag content" do
    mapping = [%{"property" => "og:type", "content" => "article"}]

    result = MetaTagResolver.resolve(mapping, %{}, %{}, @config)

    assert [%{"property" => "og:type", "content" => "article"}] = result
  end

  test "resolves dynamic field references" do
    mapping = [
      %{"property" => "og:title", "content" => "{title}"},
      %{"property" => "og:image", "content" => "{fields.image_url}"}
    ]
    fields = %{"image_url" => "https://example.com/img.jpg"}
    manifest = %{title: "My Page"}

    result = MetaTagResolver.resolve(mapping, fields, manifest, @config)

    assert Enum.find(result, &(&1["property"] == "og:title"))["content"] == "My Page"
    assert Enum.find(result, &(&1["property"] == "og:image"))["content"] == "https://example.com/img.jpg"
  end

  test "handles multiple meta tags" do
    mapping = [
      %{"name" => "description", "content" => "{fields.excerpt}"},
      %{"property" => "og:site_name", "content" => "{site_name}"}
    ]
    fields = %{"excerpt" => "A great article about things"}

    result = MetaTagResolver.resolve(mapping, fields, %{}, @config)

    assert length(result) == 2
    assert Enum.find(result, &(&1["name"] == "description"))["content"] == "A great article about things"
    assert Enum.find(result, &(&1["property"] == "og:site_name"))["content"] == "Test Site"
  end
end
