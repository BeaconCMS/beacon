defmodule Beacon.ConfigTest do
  use ExUnit.Case, async: true

  alias Beacon.Config

  describe "template_formats" do
    test "preserve default config" do
      assert %{
               template_formats: [
                 {:heex, "HEEx (HTML)"},
                 {:markdown, "Markdown (GitHub Flavored version)"}
               ]
             } = Config.new(template_formats: [])
    end

    test "merge existing config" do
      assert %{
               template_formats: [
                 {:markdown, "Markdown (GitHub Flavored version)"},
                 {:heex, "Custom HEEx description"}
               ]
             } = Config.new(template_formats: [{:heex, "Custom HEEx description"}])
    end

    test "add config" do
      assert %{
               template_formats: [
                 {:heex, "HEEx (HTML)"},
                 {:markdown, "Markdown (GitHub Flavored version)"},
                 {:custom_format, "Custom Format"}
               ]
             } = Config.new(template_formats: [{:custom_format, "Custom Format"}])
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
                 upload_asset: [{:thumbnail, _}]
               ]
             } = Config.new(lifecycle: [load_template: []])
    end
  end

  describe "assets" do
    test "sets defaults" do
      assert [
               {"image/jpeg",
                [
                  {:processor, _},
                  {:validations, []},
                  {:backends, [Beacon.MediaLibrary.Backend.Repo]}
                ]},
               {"image/gif",
                [
                  {:processor, _},
                  {:validations, []},
                  {:backends, [Beacon.MediaLibrary.Backend.Repo]}
                ]},
               {"image/png",
                [
                  {:processor, _},
                  {:validations, []},
                  {:backends, [Beacon.MediaLibrary.Backend.Repo]}
                ]},
               {"image/webp",
                [
                  {:processor, _},
                  {:validations, []},
                  {:backends, [Beacon.MediaLibrary.Backend.Repo]}
                ]}
             ] = Config.new([]).assets
    end
  end

  describe "config_for_media_type/2" do
    test "retrieves" do
      media_type = "image/jpeg"
      config = Config.new([])

      assert [
               {:processor, _},
               {:validations, []},
               {:backends, [Beacon.MediaLibrary.Backend.Repo]}
             ] = Config.config_for_media_type(config, media_type)
    end
  end
end
