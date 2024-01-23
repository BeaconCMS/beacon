defmodule Beacon.Template.HEEx.HEExDecoderTest do
  use Beacon.DataCase

  alias Beacon.Template.HEEx.HEExDecoder
  alias Beacon.Template.HEEx.JSONEncoder
  import Beacon.Fixtures

  defp assert_equal(input, assigns \\ %{}, site \\ :my_site) do
    assert {:ok, encoded} = JSONEncoder.encode(site, input, assigns)
    decoded = HEExDecoder.decode(encoded)
    assert String.trim(decoded) == String.trim(input)
  end

  test "html elements with attrs" do
    assert_equal(~S|<div>content</div>|)
    assert_equal(~S|<a href="/contact">contact</a>|)
    assert_equal(~S|<span class="bg-red text-sm">warning</span>|)
  end

  test "comments" do
    assert_equal(~S|<!-- comment -->|)

    if Version.match?(System.version(), ">= 1.15.0") do
      assert_equal(~S|<%!-- comment --%>|)
      assert_equal(~S|<%!-- <%= expr %> --%>|)
    end
  end

  test "eex expressions" do
    assert_equal(~S|<%= _a = true %>|)
    assert_equal(~S|value: <%= 1 %>|)
    assert_equal(~S|<% _a = 1 %>|)

    assert_equal(~S"""
    <%= if @completed do %>
      Congrats
    <% else %>
      Keep working
    <% end %>
    """)

    assert_equal(~S"""
    <%= case @users do %>
      <% users when is_list(users) -> %>
        <div>Users</div>
      <% :error -> %>
        <div>Not Found</div>
      <% _ -> %>
        <div>Something went wrong</div>
    <% end %>
    """)
  end

  test "comprehensions" do
    assert_equal(~S"""
    <%= for val <- @beacon_live_data[:vals] do %>
      <%= val %>
    <% end %>
    """)
  end

  test "function components" do
    assert_equal(~S|<BeaconWeb.Components.image name="logo.jpg" width="200px" />|)
    assert_equal(~S|<.link path="/contact" replace={true}>Book meeting</.link>|)
  end

  test "my_component" do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    component_fixture(site: :my_site)
    Beacon.Loader.load_components(:my_site)

    assert_equal(~S|<%= my_component("sample_component", %{val: 1}) %>|)
  end

  test "live data assigns" do
    assert_equal(~S|<%= @beacon_live_data[:name] %>|, %{beacon_live_data: %{name: "Beacon"}})
  end
end
