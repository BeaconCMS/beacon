defmodule Beacon.Loader.RoutesTest do
  use Beacon.Web.ConnCase, async: true
  use Beacon.Test

  try do
    Beacon.Loader.ensure_loaded!([:"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"], :s3_site)

    # By adding this extra layer of delegation, it ensures the above call will be complete before
    # attempting to import the Routes module.
    defmodule MyRoutes do
      import :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"

      defdelegate beacon_media_path(path), to: :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"
      defdelegate beacon_media_url(path), to: :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"
      defdelegate public_site_url, to: :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"
      defdelegate public_page_url(page), to: :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"
      defdelegate public_sitemap_url, to: :"Elixir.Beacon.Web.LiveRenderer.c55c9d9db8d6d8c4d34b4f249c20ed4e.Routes"

      def path("/"), do: ~p"/"
      def path("/contact"), do: ~p"/contact"
      def path("/posts/" <> page_id), do: ~p"/posts/#{page_id}"

      def posts_page_path(page), do: ~p"/posts/#{page}"

      def page_path(page), do: ~p"/#{page}"
    end

    test "beacon_media_path" do
      assert MyRoutes.beacon_media_path("logo.webp") == "/nested/media/__beacon_media__/logo.webp"
    end

    test "beacon_media_url" do
      assert MyRoutes.beacon_media_url("logo.webp") == "http://site_a.com/nested/media/__beacon_media__/logo.webp"
    end

    test "public_site_url" do
      assert MyRoutes.public_site_url() == "http://site_a.com/nested/media"
    end

    test "public_page_url" do
      assert MyRoutes.public_page_url(%Beacon.Content.Page{site: :s3_site, path: "/"}) == "http://site_a.com/nested/media/"
      assert MyRoutes.public_page_url(%Beacon.Content.Page{site: :s3_site, path: "/about"}) == "http://site_a.com/nested/media/about"
    end

    test "public_sitemap_url" do
      assert MyRoutes.public_sitemap_url() == "http://site_a.com/nested/media/sitemap.xml"
    end

    describe "sigil_p" do
      test "static" do
        assert MyRoutes.path("/") == "/nested/media"
        assert MyRoutes.path("/contact") == "/nested/media/contact"
      end

      test "derive path from page" do
        page = beacon_page_fixture(site: :s3_site, path: "/elixir-lang")

        assert MyRoutes.page_path(page) == "/nested/media/elixir-lang"
        assert MyRoutes.posts_page_path(page) == "/nested/media/posts/elixir-lang"
      end

      test "with dynamic segments" do
        page = %{id: 1}

        assert MyRoutes.path("/posts/#{page.id}") == "/nested/media/posts/1"
        assert MyRoutes.path("/posts/#{"a b"}") == "/nested/media/posts/a%20b"
      end
    end
  rescue
    _ ->
      nil
  end
end
