defmodule Beacon.Template.HEExTest do
  use Beacon.DataCase, async: false

  alias Beacon.Template.HEEx
  use Beacon.Test

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

    test "comprehensions" do
      assert HEEx.render(
               :my_site,
               ~S|
                  <%= for val <- @vals do %>
                    <%= val %>
                  <% end %>
                |,
               %{vals: [1, 2]}
             ) == "\n1\n\n2\n"
    end

    test "user defined components" do
      beacon_component_fixture(site: "my_site", name: "sample")

      assert HEEx.render(:my_site, ~S|<%= my_component("sample", %{project: %{id: 1, name: "Beacon"}}) %>|, %{}) ==
               ~S|<span id="project-1">Beacon</span>|

      assert HEEx.render(:my_site, ~S|<.sample project={%{id: 1, name: "Beacon"}} />|, %{}) == ~S|<span id="project-1">Beacon</span>|
    end
  end
end
