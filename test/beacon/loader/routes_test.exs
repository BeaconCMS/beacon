defmodule Beacon.Loader.RoutesTest do
  use Beacon.DataCase, async: true
  use Beacon.Test

  @router_module :"Elixir.Beacon.Web.LiveRenderer.fb13425603d2684189757bc0a91e1833.Routes"

  setup do
    Process.flag(:error_handler, Beacon.ErrorHandler)
    :ok
  end

  test "beacon_asset_path" do
    assert @router_module.beacon_asset_path("logo.webp") == "/__beacon_assets__/booted/logo.webp"
  end

  test "beacon_asset_url" do
    assert @router_module.beacon_asset_url("logo.webp") == "http://localhost:4000/__beacon_assets__/booted/logo.webp"
  end

  describe "sigil_p" do
    test "static" do
      assert @router_module.sigil_p("/") == "/nested/site"
      assert @router_module.sigil_p("/contact") == "/nested/site/contact"
    end

    test "derive path from page" do
      page = beacon_page_fixture(site: :booted, path: "/elixir-lang")

      assert @router_module.sigil_p("/#{page}") == "/nested/site/elixir-lang"
      assert @router_module.sigil_p("/posts/#{page}") == "/nested/site/posts/elixir-lang"
    end

    test "with dynamic segments" do
      page = %{id: 1}

      assert @router_module.sigil_p("/posts/#{page.id}") == "/nested/site/posts/1"
      assert @router_module.sigil_p("/posts/#{"a b"}") == "/nested/site/posts/a%20b"
    end
  end
end
