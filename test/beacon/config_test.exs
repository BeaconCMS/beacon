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
                 create_page: [],
                 publish_page: []
               ]
             } = Config.new(lifecycle: [load_template: []])
    end
  end
end
