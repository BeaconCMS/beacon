defmodule Beacon.RuntimeCSSTest do
  use Beacon.DataCase, async: true

  alias Beacon.RuntimeCSS

  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Pages
  alias Beacon.Stylesheets

  import ExUnit.CaptureIO

  @config_template """
  module.exports = {
    prefix: 'bcms-test-',
    content: [ {raw: `<%= @raw %>`} ],
    theme: { extend: {} },
  }
  """

  defp create_page(_) do
    capture_io(fn ->
      Stylesheets.create_stylesheet!(%{
        site: "my_site",
        name: "sample_stylesheet",
        content: "body {cursor: zoom-in;}"
      })

      Components.create_component!(%{
        site: "my_site",
        name: "sample_component",
        body: ~S"""
        <li id={"my-component-#{@val}"}>
          <span class="bcms-test-text-sm"><%= @val %></span>
        </li>
        """
      })

      layout =
        Layouts.create_layout!(%{
          site: "my_site",
          title: "Sample Home Page",
          meta_tags: %{"foo" => "bar"},
          stylesheet_urls: [],
          body: """
          <header class="bcms-test-text-lg">Page header</header>
          <%= @inner_content %>
          <footer class="text-md">Page footer</footer>
          """
        })

      page =
        Pages.create_page!(%{
          path: "home",
          site: "my_site",
          layout_id: layout.id,
          template: """
          <main>
            <h2 class="bcms-test-text-xl">Some Values:</h2>
            <ul>
              <%= for val <- @beacon_live_data[:vals] do %>
                <%= my_component("sample_component", val: val) %>
              <% end %>
            </ul>

            <.form let={f} for={:greeting} phx-submit="hello">
              Name: <%= text_input f, :name %>
              <%= submit "Hello" %>
            </.form>

            <%= if assigns[:message], do: assigns.message %>
          </main>
          """
        })

      Pages.create_page_event!(%{
        page_id: page.id,
        event_name: "hello",
        code: """
          {:noreply, Phoenix.LiveView.assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
        """
      })

      send(self(), {:ok, layout: layout, page: page})
    end)

    assert_received {:ok, result}

    {:ok, result}
  end

  describe "compile!/2" do
    @describetag :runtime_css
    setup [:create_page]

    test "includes classes from the database", %{layout: layout} do
      capture_io(fn ->
        assert output = RuntimeCSS.compile!(layout, config_template: @config_template)
        refute output =~ "text-md"
        assert output =~ "bcms-test-text-sm"
        assert output =~ "bcms-test-text-lg"
        assert output =~ "bcms-test-text-xl"
      end)
    end
  end
end
