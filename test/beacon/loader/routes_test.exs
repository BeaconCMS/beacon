defmodule Beacon.Loader.RoutesTest do
  use Beacon.DataCase, async: true
  use Beacon.Test

  @before_compile Beacon.ErrorHandlerCompileHook

  test "beacon_asset_path" do
    import :"Elixir.Beacon.Web.LiveRenderer.fb13425603d2684189757bc0a91e1833.Routes"
    assert beacon_asset_path("logo.webp") == "/__beacon_assets__/booted/logo.webp"
  end

  test "beacon_asset_url" do
    import :"Elixir.Beacon.Web.LiveRenderer.fb13425603d2684189757bc0a91e1833.Routes"
    assert beacon_asset_url("logo.webp") == "http://localhost:4000/__beacon_assets__/booted/logo.webp"
  end

  describe "sigil_p" do
    test "static" do
      import :"Elixir.Beacon.Web.LiveRenderer.fb13425603d2684189757bc0a91e1833.Routes"
      assert ~p"/" == "/nested/site"
      assert ~p"/contact" == "/nested/site/contact"
    end

    test "derive path from page" do
      import :"Elixir.Beacon.Web.LiveRenderer.fb13425603d2684189757bc0a91e1833.Routes"
      page = beacon_page_fixture(site: :booted, path: "/elixir-lang")
      assert ~p"/#{page}" == "/nested/site/elixir-lang"
      assert ~p"/posts/#{page}" == "/nested/site/posts/elixir-lang"
    end

    test "with dynamic segments" do
      import :"Elixir.Beacon.Web.LiveRenderer.fb13425603d2684189757bc0a91e1833.Routes"
      page = %{id: 1}
      assert ~p|/posts/#{page.id}| == "/nested/site/posts/1"

      assert ~p|/posts/#{"a b"}| == "/nested/site/posts/a%20b"
    end
  end
end
