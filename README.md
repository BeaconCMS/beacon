# Beacon

Steps to build a Phoenix app using Beacon:

1.  Make sure your phx_new package is up to date:

    ```shell
    mix archive.install hex phx_new
    ```

2.  Create either a single or umbrella phoenix app:

    * Single app:

    ```shell
    mix phx.new --install my_app
    ```

    * Or Umbrella app:

    ```shell
    mix phx.new --umbrella --install my_app
    ```

Beacon supports both.

3.  Add :beacon as a dependency:

    If the project is a single app, add beacon to your root `mix.exs` file:

    ```elixir
      {:beacon, github: "beaconCMS/beacon"}
    ```

    Or to both apps `my_app` and `my_app_web` if running in an Umbrella app.

4.  Update your deps:

    ```shell
    mix deps.get
    ```

5.  Add `Beacon.Repo` to `config :my_app, ecto_repos: [MyApp.Repo, Beacon.Repo]` in `config.exs`

6.  Configure the Beacon Repo in your dev.exs and prod.exs:

    ```elixir
    config :beacon, Beacon.Repo,
      username: "postgres",
      password: "postgres",
      database: "my_app_beacon",
      hostname: "localhost",
      show_sensitive_data_on_connection_error: true,
      pool_size: 10
    ```

7.  Create a `BeaconDataSource` module that implements `Beacon.DataSource.Behaviour`:

    ```elixir
    defmodule MyApp.BeaconDataSource do
      @behaviour Beacon.DataSource.Behaviour

      def live_data("my_site", ["home"], _params), do: %{vals: ["first", "second", "third"]}
      def live_data("my_site", ["blog", blog_slug], _params), do: %{blog_slug_uppercase: String.upcase(blog_slug)}
      def live_data(_, _, _), do: %{}
    end
    ```

8.  Add that DataSource to your config.exs:

    ```elixir
    config :beacon,
      data_source: MyApp.BeaconDataSource
    ```

9.  Add a `:beacon` pipeline to your router:

    ```elixir
    pipeline :beacon do
      plug BeaconWeb.Plug
    end
    ```

10. Add a `BeaconWeb` scope to your router as shown below:

    ```elixir
    scope "/", BeaconWeb do
      pipe_through :browser
      pipe_through :beacon

      live_session :beacon, session: %{"beacon_site" => "my_site"} do
        live "/beacon/*path", PageLive, :path
      end
    end
    ```

11. Add some seeds to your seeds.exs:

    ```elixir
    alias Beacon.Components
    alias Beacon.Pages
    alias Beacon.Layouts
    alias Beacon.Stylesheets

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

    %{id: page_id} =
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

          <.form let={f} for={:greeting} phx-submit="hello">
            Name: <%= text_input f, :name %> <%= submit "Hello" %>
          </.form>

          <%= if assigns[:message], do: assigns.message %>

          <%= dynamic_helper("upcase", "Beacon") %>
        </main>
        """
      })

    Pages.create_page!(%{
      path: "blog/:blog_slug",
      site: "my_site",
      layout_id: layout_id,
      template: """
      <main>
        <h2>A blog</h2>
        <ul>
          <li>Path Params Blog Slug: <%= @beacon_path_params.blog_slug %></li>
          <li>Live Data blog_slug_uppercase: <%= @beacon_live_data.blog_slug_uppercase %></li>
        </ul>
      </main>
      """
    })

    Pages.create_page_event!(%{
      page_id: page_id,
      event_name: "hello",
      code: """
        {:noreply, Phoenix.LiveView.assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
      """
    })

    Pages.create_page_helper!(%{
      page_id: page.id,
      helper_name: "upcase",
      helper_args: "name",
      code: """
        String.upcase(name)
      """
    })
    ```

12. Create database and run seeds:


    ```shell
    mix ecto.reset
    ```

13. Start server:

    ```shell
    mix phx.server
    ```

14. visit <http://localhost:4000/beacon/home> and note:

- The Header and Footer from the layout
- The list element from the page
- The three components rendered with the beacon_live_data from your DataSource
- The zoom in cursor from the stylesheet

15. visit <http://localhost:4000/beacon/blog/beacon_is_awesome> and note:

- The Header and Footer from the layout
- The path params blog slug
- The live data blog_slug_uppercase
- The zoom in cursor from the stylesheet

To enable Page Management UI:

1.  Add the following to the top of your Router:
    ```elixir
    require BeaconWeb.PageManagement
    ```
2.  Add the following scope to your Router:

    ```elixir
      scope "/page_management", BeaconWeb.PageManagement do
        pipe_through :browser

        BeaconWeb.PageManagement.routes()
      end
    ```

3.  visit <http://localhost:4000/page_management/pages>
4.  Edit the existing page or create a new page then click edit to go to the Page Editor (including version management)

To enable Page Management API:

1.  Add the following to the top of your Router:
    ```elixir
    require BeaconWeb.PageManagementApi
    ```
2.  Add the following scope to your Router:

    ```elixir
      scope "/page_management_api", BeaconWeb.PageManagementApi do
        pipe_through :api

        BeaconWeb.PageManagementApi.routes()
      end
    ```

3.  Check out /lib/beacon_web/page_management_api.ex for currently available API endpoints.
