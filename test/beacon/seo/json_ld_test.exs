defmodule Beacon.SEO.JsonLdTest do
  use ExUnit.Case, async: true

  alias Beacon.SEO.JsonLd

  @base_url "https://example.com"

  defp config(overrides \\ %{}) do
    base = %{
      site: :test_site,
      site_name: nil,
      organization: nil,
      search_action_url_template: nil,
      default_og_image: nil
    }
    Map.merge(base, overrides)
  end

  describe "breadcrumb_schema/2" do
    test "returns nil for root path" do
      assert JsonLd.breadcrumb_schema("/", @base_url) == nil
    end

    test "returns nil for nil path" do
      assert JsonLd.breadcrumb_schema(nil, @base_url) == nil
    end

    test "builds breadcrumbs from multi-segment path" do
      schema = JsonLd.breadcrumb_schema("/blog/authors/john", @base_url)

      assert schema["@type"] == "BreadcrumbList"
      items = schema["itemListElement"]
      assert length(items) == 4

      assert Enum.at(items, 0)["name"] == "Home"
      assert Enum.at(items, 0)["position"] == 1
      assert Enum.at(items, 0)["item"] == "https://example.com"

      assert Enum.at(items, 1)["name"] == "Blog"
      assert Enum.at(items, 1)["position"] == 2
      assert Enum.at(items, 1)["item"] == "https://example.com/blog"

      assert Enum.at(items, 2)["name"] == "Authors"
      assert Enum.at(items, 2)["position"] == 3
      assert Enum.at(items, 2)["item"] == "https://example.com/blog/authors"

      # Last item has no URL (current page)
      assert Enum.at(items, 3)["name"] == "John"
      assert Enum.at(items, 3)["position"] == 4
      refute Map.has_key?(Enum.at(items, 3), "item")
    end

    test "single segment path produces Home + page" do
      schema = JsonLd.breadcrumb_schema("/blog", @base_url)
      items = schema["itemListElement"]
      assert length(items) == 2
      assert Enum.at(items, 0)["name"] == "Home"
      assert Enum.at(items, 1)["name"] == "Blog"
    end

    test "title-cases hyphenated segments" do
      schema = JsonLd.breadcrumb_schema("/case-studies/my-project", @base_url)
      items = schema["itemListElement"]
      assert Enum.at(items, 1)["name"] == "Case Studies"
      assert Enum.at(items, 2)["name"] == "My Project"
    end
  end

  describe "organization_schema/2" do
    test "returns nil when no organization configured" do
      assert JsonLd.organization_schema(config(), @base_url) == nil
    end

    test "builds Organization schema from config" do
      cfg = config(%{
        site_name: "Test Corp",
        organization: %{
          name: "Test Corporation",
          logo: "https://example.com/logo.png",
          url: "https://example.com",
          same_as: ["https://twitter.com/test", "https://linkedin.com/company/test"]
        }
      })

      schema = JsonLd.organization_schema(cfg, @base_url)

      assert schema["@type"] == "Organization"
      assert schema["name"] == "Test Corporation"
      assert schema["logo"] == "https://example.com/logo.png"
      assert schema["sameAs"] == ["https://twitter.com/test", "https://linkedin.com/company/test"]
    end

    test "falls back to site_name for organization name" do
      cfg = config(%{
        site_name: "Fallback Name",
        organization: %{logo: "https://example.com/logo.png"}
      })

      schema = JsonLd.organization_schema(cfg, @base_url)
      assert schema["name"] == "Fallback Name"
    end
  end

  describe "website_schema/2" do
    test "returns nil when no site_name configured" do
      assert JsonLd.website_schema(config(), @base_url) == nil
    end

    test "builds WebSite schema with site_name" do
      schema = JsonLd.website_schema(config(%{site_name: "My Site"}), @base_url)

      assert schema["@type"] == "WebSite"
      assert schema["name"] == "My Site"
      assert schema["url"] == "https://example.com"
    end

    test "includes SearchAction when configured" do
      cfg = config(%{
        site_name: "My Site",
        search_action_url_template: "https://example.com/search?q={search_term_string}"
      })

      schema = JsonLd.website_schema(cfg, @base_url)

      assert schema["potentialAction"]["@type"] == "SearchAction"
      assert schema["potentialAction"]["target"] == "https://example.com/search?q={search_term_string}"
    end
  end

  describe "merge/2" do
    test "manual schemas take precedence over auto by @type" do
      auto = [
        %{"@type" => "Article", "headline" => "Auto Title"},
        %{"@type" => "BreadcrumbList", "itemListElement" => []}
      ]

      manual = [
        %{"@type" => "Article", "headline" => "Manual Title", "extra" => "field"}
      ]

      merged = JsonLd.merge(auto, manual)

      assert length(merged) == 2
      article = Enum.find(merged, &(&1["@type"] == "Article"))
      assert article["headline"] == "Manual Title"
      assert article["extra"] == "field"
      assert Enum.any?(merged, &(&1["@type"] == "BreadcrumbList"))
    end

    test "keeps all when no overlap" do
      auto = [%{"@type" => "BreadcrumbList"}]
      manual = [%{"@type" => "Article"}]

      merged = JsonLd.merge(auto, manual)
      assert length(merged) == 2
    end

    test "handles empty lists" do
      assert JsonLd.merge([], []) == []
      assert JsonLd.merge([%{"@type" => "Article"}], []) == [%{"@type" => "Article"}]
      assert JsonLd.merge([], [%{"@type" => "Article"}]) == [%{"@type" => "Article"}]
    end
  end
end
