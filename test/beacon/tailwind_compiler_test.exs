defmodule Beacon.RuntimeCSS.TailwindCompilerTest do
  use Beacon.DataCase, async: false

  import ExUnit.CaptureIO
  import Beacon.Test.Fixtures
  alias Beacon.RuntimeCSS.TailwindCompiler

  @site :my_site

  defp create_page(_) do
    beacon_stylesheet_fixture()

    beacon_component_fixture(
      template: ~S"""
      <li id={"my-component-#{@val}"}>
        <span class="text-gray-50"><%= @val %></span>
      </li>
      """
    )

    layout =
      beacon_published_layout_fixture(
        template: """
        <header class="text-gray-100">Page header</header>
        <%= @inner_content %>
        """
      )

    beacon_published_page_fixture(
      layout_id: layout.id,
      path: "/tailwind-test",
      template: """
      <main>
        <h2 class="text-gray-200">Some Values:</h2>
        <%= for val <- @vals do %>
          <%= my_component("sample_component", val: val) %>
        <% end %>
      </main>
      """
    )

    beacon_published_page_fixture(
      layout_id: layout.id,
      path: "/tailwind-test-post-process",
      template: """
      <main>
        <h2 class="text-gray-200">Some Values:</h2>
        <%= for val <- @vals do %>
          <%= my_component("sample_component", val: val) %>
        <% end %>
      </main>
      """
    )

    beacon_page_fixture(
      layout_id: layout.id,
      path: "/b",
      template: """
      <main>
        <h2 class="text-gray-300">Some Values:</h2>
      </main>
      """
    )

    :ok
  end

  test "config" do
    assert TailwindCompiler.config(@site) =~ "export default"
  end

  describe "compile site" do
    setup [:create_page]

    test "includes classes from all resources" do
      capture_io(fn ->
        assert {:ok, output} = TailwindCompiler.compile(@site)

        # test/support/templates/*.*ex
        assert output =~ "text-red-50"
        assert output =~ "text-red-100"

        # component, layout and page
        assert output =~ "text-gray-50"
        assert output =~ "text-gray-100"
        assert output =~ "text-gray-200"
      end)
    end

    test "do not include classes from unpublished pages" do
      capture_io(fn ->
        assert {:ok, output} = TailwindCompiler.compile(@site)

        refute output =~ "text-gray-300"
      end)
    end

    test "fetch post processed page templates" do
      assert {:ok, output} = TailwindCompiler.compile(@site)
      assert output =~ "text-blue-200"
    end
  end
end
