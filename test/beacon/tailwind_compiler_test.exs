defmodule Beacon.TailwindCompilerTest do
  use Beacon.DataCase, async: false

  import ExUnit.CaptureIO
  import Beacon.Fixtures
  alias Beacon.TailwindCompiler

  @site :my_site

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
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

  describe "compile template" do
    test "compile a specific template binary with custom tailwind config" do
      capture_io(fn ->
        config = Beacon.Registry.config!(@site)
        Registry.register(Beacon.Registry, {:site, :test_tailwind_compile_template}, config)

        Beacon.Registry.update_config(:test_tailwind_compile_template, fn config ->
          %{config | tailwind_config: Path.join([File.cwd!(), "test", "support", "tailwind.config.custom.js.eex"])}
        end)

        {:ok, css} = TailwindCompiler.compile(:test_tailwind_compile_template, ~S|<div class="text-gray-50">|)
        assert css =~ "text-gray-50"
      end)
    end
  end

  test "compile templates" do
    capture_io(fn ->
      templates = [
        ~S|<div class="text-gray-50">|,
        ~S|<div class="font-bold">|
      ]

      {:ok, css} = TailwindCompiler.compile(@site, templates)
      assert css =~ "text-gray-50"
      assert css =~ "font-bold"
    end)
  end
end
