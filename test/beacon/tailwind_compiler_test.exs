defmodule Beacon.TailwindCompilerTest do
  use Beacon.DataCase, async: false

  import ExUnit.CaptureIO
  import Beacon.Fixtures
  alias Beacon.TailwindCompiler

  @site :my_site

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

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
      path: "/a",
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

    Beacon.Loader.load_stylesheets(@site)
    Beacon.Loader.load_components(@site)
    Beacon.Loader.load_layouts(@site)
    Beacon.Loader.load_pages(@site)
    Beacon.Loader.load_runtime_css(@site)

    :ok
  end

  describe "compile/2" do
    setup [:create_page]

    test "includes classes from all resources" do
      capture_io(fn ->
        assert {:ok, output} = TailwindCompiler.compile(:my_site)

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
        assert {:ok, output} = TailwindCompiler.compile(:my_site)

        refute output =~ "text-gray-300"
      end)
    end
  end
end
