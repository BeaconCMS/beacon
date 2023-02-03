defmodule Beacon.TailwindCompilerTest do
  use Beacon.DataCase, async: true

  import ExUnit.CaptureIO
  import Beacon.Fixtures
  alias Beacon.TailwindCompiler

  @default_config """
  module.exports = {
    prefix: 'bcms-test-',
    content: [
      <%= @beacon_content %>
    ]
  }
  """

  @config_with_custom_content """
  module.exports = {
    prefix: 'bcms-test-',
    content: [
      'test/support/templates/*.*ex',
      <%= @beacon_content %>
    ]
  }
  """

  defp create_page(_) do
    capture_io(fn ->
      stylesheet_fixture()

      component_fixture(
        body: ~S"""
        <li id={"my-component-#{@val}"}>
          <span class="bcms-test-text-gray-50"><%= @val %></span>
        </li>
        """
      )

      layout =
        layout_fixture(
          body: """
          <header class="bcms-test-text-gray-100">Page header</header>
          <%= @inner_content %>
          """
        )

      page_fixture(
        layout_id: layout.id,
        template: """
        <main>
          <h2 class="bcms-test-text-gray-200">Some Values:</h2>
          <%= for val <- @beacon_live_data[:vals] do %>
            <%= my_component("sample_component", val: val) %>
          <% end %>
        </main>
        """
      )

      send(self(), {:ok, layout: layout})
    end)

    assert_received {:ok, result}

    {:ok, result}
  end

  describe "compile!/2" do
    setup [:create_page]

    test "inject classes from layouts", %{layout: layout} do
      capture_io(fn ->
        assert output = TailwindCompiler.compile!(layout, config_template: @default_config)
        assert output =~ "bcms-test-text-gray-50"
        assert output =~ "bcms-test-text-gray-100"
        assert output =~ "bcms-test-text-gray-200"
      end)
    end

    test "includes classes from custom content", %{layout: layout} do
      capture_io(fn ->
        assert output = TailwindCompiler.compile!(layout, config_template: @config_with_custom_content)
        assert output =~ "bcms-test-text-red-50"
        assert output =~ "bcms-test-text-red-100"

        # always inject from layout if available
        assert output =~ "bcms-test-text-gray-50"
        assert output =~ "bcms-test-text-gray-100"
        assert output =~ "bcms-test-text-gray-200"
      end)
    end
  end
end
