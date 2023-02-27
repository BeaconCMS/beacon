defmodule Beacon.TailwindCompilerTest do
  use Beacon.DataCase, async: true

  import ExUnit.CaptureIO
  import Beacon.Fixtures
  alias Beacon.TailwindCompiler

  defp create_page(_) do
    capture_io(fn ->
      stylesheet_fixture()

      component_fixture(
        body: ~S"""
        <li id={"my-component-#{@val}"}>
          <span class="text-gray-50"><%= @val %></span>
        </li>
        """
      )

      layout =
        layout_fixture(
          body: """
          <header class="text-gray-100">Page header</header>
          <%= @inner_content %>
          """
        )

      page_fixture(
        layout_id: layout.id,
        template: """
        <main>
          <h2 class="text-gray-200">Some Values:</h2>
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

    test "includes classes from custom content", %{layout: layout} do
      capture_io(fn ->
        assert output = TailwindCompiler.compile!(layout)

        # test/support/templates/*.*ex
        assert output =~ "text-red-50"
        assert output =~ "text-red-100"

        # component, layout and page
        assert output =~ "text-gray-50"
        assert output =~ "text-gray-100"
        assert output =~ "text-gray-200"
      end)
    end
  end
end
