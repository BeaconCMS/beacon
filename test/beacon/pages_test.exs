defmodule Beacon.PagesTest do
  use Beacon.DataCase, async: true

  alias Beacon.Pages
  alias Beacon.Layouts
  alias Beacon.Components
  alias Beacon.Stylesheets
  alias Beacon.Pages.Page

  defp create_page do
    Stylesheets.create_stylesheet!(%{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })

    Components.create_component!(%{
      site: "my_site",
      name: "sample_component",
      body: """
      <li>
        <%= @val %>
      </li>
      """
    })

    %{id: layout_id} =
      Layouts.create_layout!(%{
        site: "my_site",
        title: "Sample Home Page",
        meta_tags: %{"foo" => "bar"},
        stylesheet_urls: [],
        body: """
        <header>
          Header
        </header>
        <%= @inner_content %>

        <footer>
          Page Footer
        </footer>
        """
      })

    Pages.create_page!(%{
      path: "home",
      site: "my_site",
      layout_id: layout_id,
      template: """
      <main>
        <h2>Some Values:</h2>
        <ul>
          <%= for val <- @beacon_live_data[:vals] do %>
            <%= my_component("sample_component", val: val) %>
          <% end %>
        </ul>
      </main>
      """
    })
  end

  describe "list_pages/1" do
    test "list pages" do
      create_page()

      assert [%Page{}] = Pages.list_pages()
    end
  end
end
