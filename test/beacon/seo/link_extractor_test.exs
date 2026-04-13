defmodule Beacon.SEO.LinkExtractorTest do
  use ExUnit.Case, async: true

  alias Beacon.SEO.LinkExtractor

  test "extracts internal links from HTML" do
    html = ~S(<div><a href="/about">About</a><a href="/blog/post-1">Post 1</a></div>)
    links = LinkExtractor.extract(html)

    assert length(links) == 2
    assert %{target_path: "/about", anchor_text: "About"} in links
    assert %{target_path: "/blog/post-1", anchor_text: "Post 1"} in links
  end

  test "excludes external links" do
    html = ~S(<a href="https://google.com">Google</a><a href="/internal">Internal</a>)
    links = LinkExtractor.extract(html)

    assert length(links) == 1
    assert hd(links).target_path == "/internal"
  end

  test "excludes anchor-only links" do
    html = ~S(<a href="#section">Section</a><a href="/page">Page</a>)
    links = LinkExtractor.extract(html)

    assert length(links) == 1
    assert hd(links).target_path == "/page"
  end

  test "excludes mailto and tel links" do
    html = ~S(<a href="mailto:test@test.com">Email</a><a href="tel:555-1234">Call</a><a href="/ok">OK</a>)
    links = LinkExtractor.extract(html)

    assert length(links) == 1
    assert hd(links).target_path == "/ok"
  end

  test "excludes javascript links" do
    html = "<a href=\"javascript:void(0)\">Click</a><a href=\"/real\">Real</a>"
    links = LinkExtractor.extract(html)

    assert length(links) == 1
  end

  test "normalizes paths by stripping query strings and fragments" do
    html = ~S(<a href="/page?foo=bar#section">Link</a>)
    links = LinkExtractor.extract(html)

    assert hd(links).target_path == "/page"
  end

  test "deduplicates links by path" do
    html = ~S(<a href="/same">One</a><a href="/same">Two</a>)
    links = LinkExtractor.extract(html)

    assert length(links) == 1
  end

  test "handles empty HTML" do
    assert LinkExtractor.extract("") == []
  end

  test "handles HTML with no links" do
    assert LinkExtractor.extract("<p>No links here</p>") == []
  end
end
