# Installation

Beacon is an application that runs on top of an existing Phoenix LiveView application. In this guide we'll install all required tools, generate a new Phoenix LiveView application, install Beacon, and generate a new site.

## TLDR

We recomment following the guide thoroughly, but if you want a short version or to just recap the main steps:

1. Install Elixir v1.14+

2. Install Phoenix v1.7+

```sh
mix archive.install hex phx_new
```

3. Setup a database

4. Generate a new Phoenix application

```sh
mix phx.new --install my_app
```

5. Add `:beacon` dependency to `mix.exs`

6. Run `mix deps.get`

7. Add `:beacon` dependency to `.formatter.exs`

8. Run `mix beacon.install --site my_site`

9. Run `mix setup`

10. Run `mix phx.server`


Visit <http://localhost:4000/my_site/home>

## Elixir 1.14 or later

The minimum required version to run Beacon is Elixir v1.14. Make sure you have at least that version installed along with Hex:

1. Check Elixir version:

```sh
elixir --version
```

2. Install or updated Hex

```sh
mix local.hex
```

If that command fails or Elixir version is outdated, please follow [Elixir Install guide](https://elixir-lang.org/install.html) to set up your environment correctly.

## Phoenix 1.7 or later

Beacon also requires a minimum Phoenix version to work properly, make sure you have the latest `phx_new` archive - the command to generate new Phoenix applications.

```sh
mix archive.install hex phx_new
```

## Database

[PostgresSQL](https://www.postgresql.org) is the default database used by Phoenix and Beacon but it also supports MySQL and SQLServer through [ecto](https://hex.pm/packages/ecto) official adapters. Make sure one of them is up and running in your environment.

## Generating a new application

We'll be using `phx_new` to generate a new application. You can run `mix help phx.new` to show the full documentation with more options, but let's use the default values for our new site:

```sh
mix phx.new --install my_app
```

Or if you prefer an Umbrella application, run instead:

```sh
mix phx.new --umbrella --install my_app
```

Beacon supports both.

After it finishes you can open the generated directory: `cd my_app`

## Installing Beacon

1. Edit `mix.exs` to add `:beacon` as a dependency:

```elixir
{:beacon, github: "beaconCMS/beacon"}
```

Or add to both apps `my_app` and `my_app_web` if running in an Umbrella app.

2. Fetch beacon dep:

```sh
mix deps.get
```

3. Add `:beacon` to `import_deps` in the .formatter.exs file:

```elixir
[
 import_deps: [:ecto, :ecto_sql, :phoenix, :beacon],
 # rest of file
]
```

4. Run `mix compile`

## Configuration and generating your first site

Beacon requires a couple of changes in your project to get your first site up and running. You can either choose to use the `beacon.install` generator provided by Beacon or make such changes manually:

### Using the generator

Run and follow the instructions:

```sh
mix beacon.install --site my_site
```

For more details please check out the docs: `mix help beacon.install`

### Manually

1. Include `Beacon.Repo` in your project's `config.exs` file:

    ```elixir
    config :my_app, ecto_repos: [MyApp.Repo, Beacon.Repo]
    ```

2. Configure the Beacon Repo in dev.exs, prod.exs, or runtime.exs as needed for your environment:

    ```elixir
    config :beacon, Beacon.Repo,
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      database: "my_app_beacon",
      pool_size: 10
    ```

    In dev.exs you may add these extra options:

    ```elixir
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
    ```

3. Create a `BeaconDataSource` module that implements `Beacon.DataSource.Behaviour`:

    ```elixir
    defmodule MyApp.BeaconDataSource do
      @behaviour Beacon.DataSource.Behaviour

      def live_data(:my_site, ["home"], _params), do: %{vals: ["first", "second", "third"]}
      def live_data(:my_site, ["blog", blog_slug], _params), do: %{blog_slug_uppercase: String.upcase(blog_slug)}
      def live_data(_, _, _), do: %{}
    end
    ```

4. Edit `lib/my_app_web/router.ex` to import `Beacon.Router`, create a new `scope`, and call `beacon_site` in your app router:

    ```elixir
    use Beacon.Router

    scope "/" do
      pipe_through :browser
      beacon_site "/my_site", site: :my_site
    end
    ```

Make sure you're not adding `beacon_site` into the existing `scope "/", MyAppWeb`, otherwise requests will fail.

5. Include the `Beacon` supervisor in the list of `children` applications in the file `lib/my_app/application.ex`:

    ```elixir
    @impl true
    def start(_type, _args) do
      children = [
        # ommited others for brevity
        {Beacon, sites: [[site: :my_site, data_source: MyApp.BeaconDataSource]]},
        MyAppWeb.Endpoint
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
    ```

For more info on site options, check out `Beacon.start_link/1`.

**Notes**
- The site identification has to be the same across your environment, in configuration, `beacon_site`, and `live_data`. In this example we're using `:my_site`.
- Include it after your app `Endpoint`.

6. Add some seeds in the seeds file `priv/repo/beacon_seeds.exs`:

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

          <.form :let={f} for={%{}} as={:greeting} phx-submit="hello">
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
      page_id: page_id,
      helper_name: "upcase",
      helper_args: "name",
      code: """
        String.upcase(name)
      """
    })
    ```

6. Include new seeds in the `ecto.setup` alias in `mix.exs`:

    ```elixir
    "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs", "run priv/repo/beacon_seeds.exs"],
    ```

## Setup database, seeds, and assets:

Feel free to edit `priv/repo/beacon_seeds.exs` as you wish and run:

```sh
mix setup
```

## Visit your new site

Run the Phoenix server:

```sh
mix phx.server
```

Open <http://localhost:4000/my_site/home> and note:

- The Header and Footer from the layout
- The list element from the page
- The three components rendered with the beacon_live_data from your DataSource
- The zoom in cursor from the stylesheet

Open <http://localhost:4000/my_site/blog/beacon_is_awesome> and note:

- The Header and Footer from the layout
- The path params blog slug
- The live data blog_slug_uppercase
- The zoom in cursor from the stylesheet
