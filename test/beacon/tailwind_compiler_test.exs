defmodule Beacon.RuntimeCSS.TailwindCompilerTest do
  use Beacon.DataCase, async: false

  import ExUnit.CaptureIO
  import Beacon.Fixtures
  alias Beacon.RuntimeCSS.TailwindCompiler

  @site :my_site

  defp create_page(_) do
    stylesheet_fixture()

    component_fixture(
      body: ~S"""
      <li id={"my-component-#{@val}"}>
        <span class="text-gray-50"><%= @val %></span>
      </li>
      """
    )

    layout =
      published_layout_fixture(
        template: """
        <header class="text-gray-100">Page header</header>
        <%= @inner_content %>
        """
      )

    published_page_fixture(
      layout_id: layout.id,
      path: "/tailwind-test",
      template: """
      <main>
        <h2 class="text-gray-200">Some Values:</h2>
        <%= for val <- @beacon_live_data[:vals] do %>
          <%= my_component("sample_component", val: val) %>
        <% end %>
      </main>
      """
    )

    published_page_fixture(
      layout_id: layout.id,
      path: "/tailwind-test-post-process",
      template: """
      <main>
        <h2 class="text-gray-200">Some Values:</h2>
        <%= for val <- @beacon_live_data[:vals] do %>
          <%= my_component("sample_component", val: val) %>
        <% end %>
      </main>
      """
    )

    page_fixture(
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
    assert TailwindCompiler.config(@site) =~ "module.exports"
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
