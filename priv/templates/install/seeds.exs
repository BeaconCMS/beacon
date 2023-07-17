

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
    stylesheet_urls: [],
    body: """
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

%{
  path: "home",
  site: "<%= site %>",
  layout_id: layout.id,
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
  ],
  events: [
    %{
      name: "hello",
      code: """
        {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
      """
    }
  ]
}
|> Content.create_page!()
|> Content.publish_page()

%{
  path: "blog/:blog_slug",
  site: "<%= site %>",
  layout_id: layout.id,
  template: """
  <main>
    <h2>A blog</h2>
    <ul>
      <li>Path Params Blog Slug: <%%= @beacon_path_params.blog_slug %></li>
      <li>Live Data blog_slug_uppercase: <%%= @beacon_live_data.blog_slug_uppercase %></li>
    </ul>
  </main>
  """
}
|> Content.create_page!()
|> Content.publish_page()

Content.create_page_event!(%{
  page_id: page_id,
  event_name: "hello",
  code: """
    {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
  """
})

navigations = ComponentCategories.create_component_category!(%{ name: "Navigations" })
headers = ComponentCategories.create_component_category!(%{ name: "Headers" })
sign_ins = ComponentCategories.create_component_category!(%{ name: "Sign in" })
sign_ups = ComponentCategories.create_component_category!(%{ name: "Sign up" })
stats = ComponentCategories.create_component_category!(%{ name: "Stats" })
footers = ComponentCategories.create_component_category!(%{ name: "Footers" })
basics = ComponentCategories.create_component_category!(%{ name: "Basics" })

ComponentDefinitions.create_component_definition!(%{
  name: 'Navigation 1',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/01_2be7c9d07f.png',
  component_category: navigations
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Navigation 2',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/02_0f54c9f964.png',
  component_category: navigations
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Navigation 3',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/03_e244675766.png',
  component_category: navigations
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Navigation 4',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/04_64390b9975.png',
  component_category: navigations
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Header 1',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png',
  component_category: headers
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Header 2',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png',
  component_category: headers
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Header 3',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png',
  component_category: headers
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Sign Up 1',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png',
  component_category: sign_ups
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Sign Up 2',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png',
  component_category: sign_ups
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Sign Up 3',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png',
  component_category: sign_ups
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Stats 1',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png',
  component_category: stats
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Stats 2',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png',
  component_category: stats
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Stats 3',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png',
  component_category: stats
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Footer 1',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png',
  component_category: footers
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Footer 2',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png',
  component_category: footers
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Footer 3',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png',
  component_category: footers
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Footer 1',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png',
  component_category: stats
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Footer 2',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png',
  component_category: stats
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Footer 3',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png',
  component_category: stats
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Sign In 1',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png',
  component_category: sign_ins
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Sign In 2',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png',
  component_category: sign_ins
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Sign In 3',
  thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png',
  component_category: sign_ins
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Title',
  thumbnail: '/component_thumbnails/title.jpg',
  component_category: basics
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Button',
  thumbnail: '/component_thumbnails/button.jpg',
  component_category: basics
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Link',
  thumbnail: '/component_thumbnails/link.jpg',
  component_category: basics
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Paragraph',
  thumbnail: '/component_thumbnails/paragraph.jpg',
  component_category: basics
})
ComponentDefinitions.create_component_definition!(%{
  name: 'Aside',
  thumbnail: '/component_thumbnails/aside.jpg',
  component_category: basics
})
# { id: ComponentDefinitionId.header_1, categoryId: ComponentCategoryId.headers, name: 'Header 1', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png' },
# { id: ComponentDefinitionId.header_2, categoryId: ComponentCategoryId.headers, name: 'Header 2', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png' },
# { id: ComponentDefinitionId.header_3, categoryId: ComponentCategoryId.headers, name: 'Header 3', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png' },
# { id: ComponentDefinitionId.signup_1, categoryId: ComponentCategoryId.signup, name: 'Sign Up 1', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png' },
# { id: ComponentDefinitionId.signup_2, categoryId: ComponentCategoryId.signup, name: 'Sign Up 2', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png' },
# { id: ComponentDefinitionId.signup_3, categoryId: ComponentCategoryId.signup, name: 'Sign Up 3', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png' },
# { id: ComponentDefinitionId.stats_1, categoryId: ComponentCategoryId.stats, name: 'Stats 1', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png' },
# { id: ComponentDefinitionId.stats_2, categoryId: ComponentCategoryId.stats, name: 'Stats 2', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png' },
# { id: ComponentDefinitionId.stats_3, categoryId: ComponentCategoryId.stats, name: 'Stats 3', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png' },
# { id: ComponentDefinitionId.footer_1, categoryId: ComponentCategoryId.footers, name: 'Footer 1', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png' },
# { id: ComponentDefinitionId.footer_2, categoryId: ComponentCategoryId.footers, name: 'Footer 2', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png' },
# { id: ComponentDefinitionId.footer_3, categoryId: ComponentCategoryId.footers, name: 'Footer 3', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png' },
# { id: ComponentDefinitionId.signin_1, categoryId: ComponentCategoryId.signin, name: 'Sign In 1', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png' },
# { id: ComponentDefinitionId.signin_2, categoryId: ComponentCategoryId.signin, name: 'Sign In 2', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png' },
# { id: ComponentDefinitionId.signin_3, categoryId: ComponentCategoryId.signin, name: 'Sign In 3', thumbnail: 'https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png' },
# { id: ComponentDefinitionId.title, categoryId: ComponentCategoryId.basics, name: 'Title', thumbnail: '/component_thumbnails/title.jpg'},
# { id: ComponentDefinitionId.button, categoryId: ComponentCategoryId.basics, name: 'Button', thumbnail: '/component_thumbnails/button.jpg'},
# { id: ComponentDefinitionId.link, categoryId: ComponentCategoryId.basics, name: 'Link', thumbnail: '/component_thumbnails/link.jpg'},
# { id: ComponentDefinitionId.paragraph, categoryId: ComponentCategoryId.basics, name: 'Paragraph', thumbnail: '/component_thumbnails/paragraph.jpg'},
# { id: ComponentDefinitionId.aside, categoryId: ComponentCategoryId.basics, name: 'Aside', thumbnail: '/component_thumbnails/aside.jpg'}
