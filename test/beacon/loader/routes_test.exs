defmodule Beacon.Loader.RoutesTest do
  use Beacon.DataCase, async: true
  use Beacon.Test

  @routes_module :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"

  setup do
    Process.flag(:error_handler, Beacon.ErrorHandler)
    Process.put(:__beacon_site__, :s3_site)
    :ok
  end

  test "beacon_media_path" do
    assert @routes_module.beacon_media_path("logo.webp") == "/nested/media/__beacon_media__/logo.webp"
  end

  test "beacon_media_url" do
    assert @routes_module.beacon_media_url("logo.webp") == "http://localhost:4000/nested/media/__beacon_media__/logo.webp"
  end

  describe "sigil_p" do
    test "static" do
      require @routes_module
      assert @routes_module.sigil_p("/", []) == "/nested/media"
      assert @routes_module.sigil_p("/contact", []) == "/nested/media/contact"
    end

    test "derive path from page" do
      require @routes_module
      page = beacon_page_fixture(site: :s3_site, path: "/elixir-lang")

      assert @routes_module.sigil_p("/#{page.id}", []) == "/nested/media/elixir-lang"
      assert @routes_module.sigil_p("/posts/#{page.id}", []) == "/nested/media/posts/elixir-lang"
    end

    test "with dynamic segments" do
      require @routes_module
      page = %{id: 1}

      assert @routes_module.sigil_p("/posts/#{page.id}", []) == "/nested/media/posts/1"
      assert @routes_module.sigil_p("/posts/#{"a b"}", []) == "/nested/media/posts/a%20b"
    end
  end
end
