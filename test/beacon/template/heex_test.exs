defmodule Beacon.Template.HEExTest do
  use Beacon.DataCase, async: false

  alias Beacon.Template.HEEx
  import Beacon.Fixtures

  describe "render" do
    test "phoenix components" do
      assert HEEx.render(
               :my_site,
               ~S|<.link patch="/contact" replace={true}><%= @text %></.link>|,
               %{text: "Book Meeting"}
             ) == ~S|<a href="/contact" data-phx-link="patch" data-phx-link-state="replace">Book Meeting</a>|
    end

    test "eex expressions" do
      assert HEEx.render(:my_site, ~S|<%= 1 + @value %>|, %{value: 1}) == "2"
    end

    test "user defined components" do
      start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
      component_fixture(site: "my_site", name: "sample")
      Beacon.Loader.load_components(:my_site)

      assert HEEx.render(
               :my_site,
               ~S|<%= my_component("sample", %{val: 1}) %>|,
               %{}
             ) == ~S|<span id="my-component-1">1</span>|
    end
  end
end
