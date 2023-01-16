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

3.  Add `:beacon` as a dependency:

    If the project is a single app, add beacon to your root `mix.exs` file:

    ```elixir
      {:beacon, github: "beaconCMS/beacon"}
    ```

    Or to both apps `my_app` and `my_app_web` if running in an Umbrella app.

4.  Update your deps:

    Make sure your application is running on Phoenix v1.7+ and Phoenix LiveView v0.18+, and execute:

    ```shell
    mix deps.get
    ```

5. Import `:beacon` in your app formatter deps:

   ```elixir
   [
     import_deps: [:ecto, :ecto_sql, :phoenix, :beacon],
     # rest of file
   ]
   ```

6.  Add `Beacon.Repo` to `config :my_app, ecto_repos: [MyApp.Repo, Beacon.Repo]` in `config.exs`

7.  Configure the Beacon Repo in your dev.exs and prod.exs:

    ```elixir
    config :beacon, Beacon.Repo,
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      database: "my_app_beacon",
      stacktrace: true,
      show_sensitive_data_on_connection_error: true,
      pool_size: 10
    ```

8.  Create a `BeaconDataSource` module that implements `Beacon.DataSource.Behaviour`:

    ```elixir
    defmodule MyApp.BeaconDataSource do
      @behaviour Beacon.DataSource.Behaviour

      def live_data("my_site", ["home"], _params), do: %{vals: ["first", "second", "third"]}
      def live_data("my_site", ["blog", blog_slug], _params), do: %{blog_slug_uppercase: String.upcase(blog_slug)}
      def live_data(_, _, _), do: %{}
    end
    ```

9. Import `Beacon.Router` and call `beacon_site` in your app router:

    ```elixir
    import Beacon.Router

    scope "/" do
      pipe_through :browser
      beacon_site "/beacon", name: "my_site", data_source: MyApp.BeaconDataSource

    end
    ```

10. Add some seeds to your seeds.exs:

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
        {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
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

11. Create database and run seeds:


    ```shell
    mix ecto.reset
    ```

12. Start server:

    ```shell
    mix phx.server
    ```

13. Visit <http://localhost:4000/beacon/home> and note:

- The Header and Footer from the layout
- The list element from the page
- The three components rendered with the beacon_live_data from your DataSource
- The zoom in cursor from the stylesheet

14. Visit <http://localhost:4000/beacon/blog/beacon_is_awesome> and note:

- The Header and Footer from the layout
- The path params blog slug
- The live data blog_slug_uppercase
- The zoom in cursor from the stylesheet

#### To enable Page Management UI:

1. Import `Beacon.Router` and call `beacon_admin` in your app router:

    ```elixir
    import Beacon.Router

    scope "/beacon" do
      pipe_through :browser
      beacon_admin "/admin"
    end
    ```

2. Visit <http://localhost:4000/beacon/admin>

3. Edit the existing page or create a new page then click edit to go to the Page Editor (including version management)

#### To enable Page Management API:

1. Import `Beacon.Router` and call `beacon_api` in your router app:

    ```elixir
    import Beacon.Router

    scope "/api"
      pipe_through :api
      beacon_api "/beacon"
    end
    ```

2. Check out /lib/beacon/router.ex for currently available API endpoints.

### Local Development

`dev.exs` provides a phoenix app running beacon with with code reload enabled:

```shell
mix deps.get
mix dev
```
