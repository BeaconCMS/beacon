defmodule BeaconWeb.API.ComponentCategoryController do
  use BeaconWeb, :controller
  alias Beacon.ComponentCategories
  alias Beacon.ComponentDefinitions

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, _params) do
    component_categories = ComponentCategories.list_component_categories
    component_definitions = ComponentDefinitions.list_component_definitions
    render(conn, :index,
      component_categories: component_categories,
      component_definitions: component_definitions
      # [
      #   %{ id: "nav_1", categoryId: "navigations", name: "Navigation 1", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/01_2be7c9d07f.png" },
      #   %{ id: "nav_2", categoryId: "navigations", name: "Navigation 2", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/02_0f54c9f964.png" },
      #   %{ id: "nav_3", categoryId: "navigations", name: "Navigation 3", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/03_e244675766.png" },
      #   %{ id: "nav_4", categoryId: "navigations", name: "Navigation 4", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/04_64390b9975.png" },
      #   %{ id: "header_1", categoryId: "headers", name: "Header 1", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png" },
      #   %{ id: "header_2", categoryId: "headers", name: "Header 2", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png" },
      #   %{ id: "header_3", categoryId: "headers", name: "Header 3", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png" },
      #   %{ id: "signup_1", categoryId: "signup", name: "Sign Up 1", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png" },
      #   %{ id: "signup_2", categoryId: "signup", name: "Sign Up 2", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png" },
      #   %{ id: "signup_3", categoryId: "signup", name: "Sign Up 3", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png" },
      #   %{ id: "stats_1", categoryId: "stats", name: "Stats 1", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png" },
      #   %{ id: "stats_2", categoryId: "stats", name: "Stats 2", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png" },
      #   %{ id: "stats_3", categoryId: "stats", name: "Stats 3", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png" },
      #   %{ id: "footer_1", categoryId: "footers", name: "Footer 1", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png" },
      #   %{ id: "footer_2", categoryId: "footers", name: "Footer 2", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png" },
      #   %{ id: "footer_3", categoryId: "footers", name: "Footer 3", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png" },
      #   %{ id: "signin_1", categoryId: "signin", name: "Sign In 1", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png" },
      #   %{ id: "signin_2", categoryId: "signin", name: "Sign In 2", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png" },
      #   %{ id: "signin_3", categoryId: "signin", name: "Sign In 3", thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png" },
      #   %{ id: "title", categoryId: "basics", name: "Title", thumbnail: "/component_thumbnails/title.jpg"},
      #   %{ id: "button", categoryId: "basics", name: "Button", thumbnail: "/component_thumbnails/button.jpg"},
      #   %{ id: "link", categoryId: "basics", name: "Link", thumbnail: "/component_thumbnails/link.jpg"},
      #   %{ id: "paragraph", categoryId: "basics", name: "Paragraph", thumbnail: "/component_thumbnails/paragraph.jpg"},
      #   %{ id: "aside", categoryId: "basics", name: "Aside", thumbnail: "/component_thumbnails/aside.jpg"}
      # ]
    )
  end

  # def show(conn, %{"id" => id}) do
  #   page = Pages.get_page!(id)
  #   render(conn, :show, page: page)
  # end
end
