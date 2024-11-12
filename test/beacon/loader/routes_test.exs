defmodule Beacon.Loader.RoutesTest do
  use Beacon.DataCase, async: true
  use Beacon.Test

  # Beacon.Loader.fetch_routes_module(:s3_site)
  import :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"

  test "beacon_media_path" do
    assert beacon_media_path("logo.webp") == "/nested/media/__beacon_media__/logo.webp"
  end

  test "beacon_media_url" do
    assert beacon_media_url("logo.webp") == "http://localhost:4000/nested/media/__beacon_media__/logo.webp"
  end

  describe "sigil_p" do
    test "static" do
      assert ~p"/" == "/nested/media"
      assert ~p"/contact" == "/nested/media/contact"
    end

    test "derive path from page" do
      page = beacon_page_fixture(site: :s3_site, path: "/elixir-lang")

      assert ~p"/#{page}" == "/nested/media/elixir-lang"
      assert ~p"/posts/#{page}" == "/nested/media/posts/elixir-lang"
    end

    test "with dynamic segments" do
      page = %{id: 1}

      assert ~p"/posts/#{page.id}" == "/nested/media/posts/1"
      assert ~p"/posts/#{"a b"}" == "/nested/media/posts/a%20b"
    end
  end
end
