# Script for populating the database. You can run it as:
#
#     mix run priv/repo/beacon_seeds.exs

alias Beacon.Content

Content.create_stylesheet!(%{
  site: "<%= site %>",
  name: "sample_stylesheet",
  content: "body {cursor: zoom-in;}"
})

Content.create_component!(%{
  site: "<%= site %>",
  name: "sample_component",
  body: """
  <li>
    <%%= @val %>
  </li>
  """
})

layout =
  Content.create_layout!(%{
    site: "<%= site %>",
    title: "Sample Home Page",
    template: """
    <header>
      Header
    </header>
    <%%= @inner_content %>

    <footer>
      Page Footer
    </footer>
    """
  })

Content.publish_layout(layout)

page =
  Content.create_page!(%{
    site: "<%= site %>",
    layout_id: layout.id,
    path: "/",
    title: "Home",
    template: """
    <main>
      <h2>Some Values:</h2>
      <ul>
        <%%= for val <- @beacon_live_data[:vals] do %>
          <%%= my_component("sample_component", val: val) %>
        <%% end %>
      </ul>

      <.form :let={f} for={%{}} as={:greeting} phx-submit="hello">
        Name: <%%= text_input f, :name %> <%%= submit "Hello" %>
      </.form>

      <%%= if assigns[:message], do: assigns.message %>

      <%%= dynamic_helper("upcase", "Beacon") %>
    </main>
    """,
    helpers: [
      %{
        name: "upcase",
        args: "name",
        code: """
          String.upcase(name)
        """
      }
    ]
  })

{:ok, page} =
  Content.create_event_handler_for_page(page, %{
    name: "hello",
    code: """
      {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
    """
  })

Content.publish_page(page)

home_live_data = Content.create_live_data!(%{site: "<%= site %>", path: "/"})

Content.create_assign_for_live_data(home_live_data, %{format: :elixir, key: "vals", value: """
["first", "second", "third"]
"""})

%{
  site: "<%= site %>",
  layout_id: layout.id,
  path: "/blog/:blog_slug",
  title: "Blog",
  template: """
  <main>
    <h2>A blog</h2>
    <ul>
      <li>Path Params Blog Slug: <%%= @beacon_path_params["blog_slug"] %></li>
      <li>Live Data blog_slug_uppercase: <%%= @beacon_live_data[:blog_slug_uppercase] %></li>
    </ul>
  </main>
  """
}
|> Content.create_page!()
|> Content.publish_page()

blog_live_data = Content.create_live_data!(%{site: "<%= site %>", path: "/blog/:blog_slug"})

Content.create_assign_for_live_data(blog_live_data, %{
  format: :elixir,
  key: "blog_slug_uppercase",
  value: "String.upcase(blog_slug)"
})
