defmodule Beacon.ConfigTest do
  use ExUnit.Case, async: true

  @site :my_site
  @repo Beacon.BeaconTest.Repo

  test "returns default when value is nil" do
    assert %Beacon.Config{
             default_meta_tags: [],
             page_warming: {:shortest_paths, 10}
           } =
             Beacon.Config.new(
               site: :site,
               endpoint: :endpoint,
               router: :router,
               repo: @repo,
               default_meta_tags: nil,
               page_warming: nil
             )
  end

  describe "registry" do
    test "returns the site config" do
      assert %Beacon.Config{
               css_compiler: Beacon.RuntimeCSS.TailwindCompiler,
               live_socket_path: "/custom_live",
               safe_code_check: false,
               site: :my_site,
               tailwind_config: tailwind_config
             } = Beacon.Config.fetch!(@site)

      assert tailwind_config =~ "tailwind.config.templates.js"
    end

    test "raises for non existing site" do
      assert_raise Beacon.ConfigError, ~r/site :invalid not found/, fn ->
        Beacon.Config.fetch!(:invalid)
      end
    end

    test "updates key from config" do
      assert %Beacon.Config{live_socket_path: "/new_live"} = Beacon.Config.update_value(:not_booted, :live_socket_path, "/new_live")
    end
  end

  describe "template_formats" do
    test "preserve default config" do
      assert %{
               template_formats: [
                 {:heex, "HEEx (HTML)"},
                 {:markdown, "Markdown (GitHub Flavored version)"}
               ]
             } = Beacon.Config.new(site: :site, endpoint: :endpoint, router: :router, repo: @repo, template_formats: [])
    end

    test "merge existing config" do
      assert %{
               template_formats: [
                 {:markdown, "Markdown (GitHub Flavored version)"},
                 {:heex, "Custom HEEx description"}
               ]
             } =
               Beacon.Config.new(
                 site: :site,
                 endpoint: :endpoint,
                 router: :router,
                 repo: @repo,
                 template_formats: [{:heex, "Custom HEEx description"}]
               )
    end

    test "add config" do
      assert %{
               template_formats: [
                 {:heex, "HEEx (HTML)"},
                 {:markdown, "Markdown (GitHub Flavored version)"},
                 {:custom_format, "Custom Format"}
               ]
             } =
               Beacon.Config.new(
                 site: :site,
                 endpoint: :endpoint,
                 router: :router,
                 repo: @repo,
                 template_formats: [{:custom_format, "Custom Format"}]
               )
    end
  end

  describe "lifecycle" do
    test "preserve default config" do
      assert %{
               lifecycle: [
                 load_template: [{:heex, _}, {:markdown, _}],
                 render_template: [{:heex, _}, {:markdown, _}],
                 after_create_page: [],
                 after_update_page: [],
                 after_publish_page: [],
                 after_unpublish_page: [],
                 upload_asset: [{:thumbnail, _}]
               ]
             } = Beacon.Config.new(site: :site, endpoint: :endpoint, router: :router, repo: @repo, lifecycle: [load_template: []])
    end
  end

  describe "assets" do
    test "sets defaults" do
      assert [
               {"image/jpeg",
                [
                  {:processor, _},
                  {:validations, []},
                  {:providers, [Beacon.MediaLibrary.Provider.Repo]}
                ]},
               {"image/gif",
                [
                  {:processor, _},
                  {:validations, []},
                  {:providers, [Beacon.MediaLibrary.Provider.Repo]}
                ]},
               {"image/png",
                [
                  {:processor, _},
                  {:validations, []},
                  {:providers, [Beacon.MediaLibrary.Provider.Repo]}
                ]},
               {"image/webp",
                [
                  {:processor, _},
                  {:validations, []},
                  {:providers, [Beacon.MediaLibrary.Provider.Repo]}
                ]},
               {"application/pdf",
                [
                  {:processor, _},
                  {:validations, []},
                  {:providers, [Beacon.MediaLibrary.Provider.Repo]}
                ]}
             ] = Beacon.Config.new(site: :site, endpoint: :endpoint, router: :router, repo: @repo).assets
    end
  end

  describe "config_for_media_type/2" do
    test "retrieves" do
      media_type = "image/jpeg"
      config = Beacon.Config.new(site: :site, endpoint: :endpoint, router: :router, repo: @repo)

      assert [
               {:processor, _},
               {:validations, []},
               {:providers, [Beacon.MediaLibrary.Provider.Repo]}
             ] = Beacon.Config.config_for_media_type(config, media_type)
    end
  end
end
