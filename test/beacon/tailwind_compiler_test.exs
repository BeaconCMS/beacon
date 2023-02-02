defmodule Beacon.TailwindCompilerTest do
  use Beacon.DataCase, async: true

  import ExUnit.CaptureIO
  import Beacon.Fixtures
  alias Beacon.TailwindCompiler

  @db_config_template """
  module.exports = {
    prefix: 'bcms-test-',
    content: [ {raw: `<%= @raw %>`} ],
    theme: { extend: {} },
  }
  """

  @file_config_template """
  module.exports = {
    prefix: 'bcms-test-',
    content: ['test/support/templates/*.*ex'],
    theme: { extend: {} },
  }
  """

  defp create_page(_) do
    capture_io(fn ->
      stylesheet_fixture()

      component_fixture(
        body: ~S"""
        <li id={"my-component-#{@val}"}>
          <span class="bcms-test-text-sm"><%= @val %></span>
        </li>
        """
      )

      layout =
        layout_fixture(
          body: """
          <header class="bcms-test-text-lg">Page header</header>
          <%= @inner_content %>
          <footer class="text-md">Page footer</footer>
          """
        )

      page_fixture(
        layout_id: layout.id,
        template: """
        <main>
          <h2 class="bcms-test-text-xl">Some Values:</h2>
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

    test "includes classes from the database", %{layout: layout} do
      capture_io(fn ->
        assert output = TailwindCompiler.compile!(layout, config_template: @db_config_template)
        refute output =~ "text-md"
        assert output =~ "bcms-test-text-sm"
        assert output =~ "bcms-test-text-lg"
        assert output =~ "bcms-test-text-xl"
      end)
    end

    test "includes classes from template files", %{layout: layout} do
      capture_io(fn ->
        assert output = TailwindCompiler.compile!(layout, config_template: @file_config_template)
        refute output =~ "text-blue-400"
        refute output =~ "text-red-100"
        assert output =~ "bcms-test-text-red-800"
        assert output =~ "bcms-test-text-blue-300"
      end)
    end
  end
end
