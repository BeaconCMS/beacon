# Installation

Beacon is an application that runs on top of an existing Phoenix LiveView application. In this guide we'll install all required tools, generate a new Phoenix LiveView application, install Beacon, and generate a new site.

## TLDR

We recommend following the guide thoroughly, but if you want a short version or to just recap the main steps:

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

  ```elixir
  {:beacon, github: "beaconCMS/beacon"}
  ```

6. Run `mix deps.get`

7. Add `:beacon` to `import_deps` in the .formatter.exs file.

8. Run `mix beacon.install --site my_site`

9. Run `mix setup`

10. Run `mix phx.server`

Visit http://localhost:4000/my_site to see the page created from seeds.

## Steps

Detailed instructions:

### Elixir 1.14 or later

The minimum required version to run Beacon is Elixir v1.14. Make sure you have at least that version installed along with Hex:

1. Check Elixir version:

```sh
elixir --version
```

2. Install or update Hex

```sh
mix local.hex
```

If that command fails or Elixir version is outdated, please follow [Elixir Install guide](https://elixir-lang.org/install.html) to set up your environment correctly.

### Phoenix 1.7 or later

Beacon also requires a minimum Phoenix version to work properly, make sure you have the latest `phx_new` archive - the command to generate new Phoenix applications.

```sh
mix archive.install hex phx_new
```

### Database

[PostgresSQL](https://www.postgresql.org) is the default database used by Phoenix and Beacon but it also supports MySQL and SQLServer through [ecto](https://hex.pm/packages/ecto) official adapters. Make sure one of them is up and running in your environment.

### Generating a new application

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

### Installing Beacon

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

### Configuration and generating your first site

Beacon requires a couple of changes in your project to get your first site up and running. You can either choose to use the `beacon.install` generator provided by Beacon or make such changes manually:

#### Using the generator

Run and follow the instructions:

```sh
mix beacon.install --site my_site
```

For more details please check out the docs: `mix help beacon.install`

#### Manually

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
      database: "db_name_replace_me",
      pool_size: 10
    ```

    In dev.exs you may add these extra options:

    ```elixir
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
    ```

3. Edit your endpoint configuration `:render_errors` key, like so:

Replace the `[formats: [html: _]]` option with `BeaconWeb.ErrorHTML`.

```diff
 # Configures the endpoint
 config :my_app, MyAppWeb.Endpoint,
   url: [host: "localhost"],
   adapter: Bandit.PhoenixAdapter,
   render_errors: [
-    formats: [html: MyAppWeb.ErrorHTML, json: MyAppWeb.ErrorJSON],
+    formats: [html: BeaconWeb.ErrorHTML, json: MyAppWeb.ErrorJSON],
     layout: false
   ],
   pubsub_server: MyApp.PubSub,
   live_view: [signing_salt: "j39Y3XwM"]
```

4. Edit `lib/my_app_web/router.ex` to add  `use Beacon.Router`, create a new `scope`, and call `beacon_site` in your app router:

    ```elixir
    use Beacon.Router

    scope "/" do
      pipe_through :browser
      beacon_site "/my_site", site: :my_site
    end
    ```

Make sure you're not adding the macro `beacon_site` into the existing `scope "/", MyAppWeb`, otherwise requests will fail.

5. Include the `Beacon` supervisor in the list of `children` applications in the file `lib/my_app/application.ex`:

    ```elixir
    @impl true
    def start(_type, _args) do
      children = [
        # ommited others for brevity
        MyAppWeb.Endpoint,
        {Beacon, sites: [[site: :my_site, endpoint: MyAppWeb.Endpoint]]}
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
    ```

For more info on site options, check out `Beacon.start_link/1`.

**Notes**
- The site identification has to be the same across your environment, in configuration and `beacon_site`. In this example we're using `:my_site`.
- Include it after your app `Endpoint`.

6. Add some seeds in the seeds file `priv/repo/beacon_seeds.exs`:

    ```elixir
    # Replace "<%= site %>" with your site name.
    # ## Example using my_site as site value:
    #
    #     Content.create_stylesheet!(%{
    #       site: "my_site",
    #       name: "sample_stylesheet",
    #       content: "body {cursor: zoom-in;}"
    #     })

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
        <%= @val %>
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
        <%= @inner_content %>

        <footer>
          Page Footer
        </footer>
        """
      })

    Content.publish_layout(layout)

    %{
      path: "/home",
      site: "<%= site %>",
      layout_id: layout.id,
      template: """
      <main>
        <h2>Some Values:</h2>
        <ul>
          <%= for val <- @beacon_live_data[:vals] do %>
            <%= my_component("sample_component", val: val) %>
          <% end %>
        </ul>

        <.form :let={f} for={%{}} as={:greeting} phx-submit="hello">
          Name: <.input type="text" field={f[:name]} /> <.button>Hello</.button>
        </.form>

        <%= if assigns[:message], do: assigns.message %>

        <%= dynamic_helper("upcase", "Beacon") %>
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

    home_live_data = Content.create_live_data!(%{site: "<%= site %>", path: "/home"})

    Content.create_assign_for_live_data(home_live_data, %{format: :elixir, key: "vals", value: """
    ["first", "second", "third"]
    """})

    %{
      path: "/blog/:blog_slug",
      site: "<%= site %>",
      layout_id: layout.id,
      template: """
      <main>
        <h2>A blog</h2>
        <ul>
          <li>Path Params Blog Slug: <%= @beacon_path_params["blog_slug"] %></li>
          <li>Live Data blog_slug_uppercase: <%= @beacon_live_data.blog_slug_uppercase %></li>
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
    ```

7. Include new seeds in the `ecto.setup` alias in `mix.exs`:

    ```elixir
    "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs", "run priv/repo/beacon_seeds.exs"],
    ```

### Setup database, seeds, and assets:

Feel free to edit `priv/repo/beacon_seeds.exs` as you wish and run:

```sh
mix setup
```

### Visit your new site

Run the Phoenix server:

```sh
mix phx.server
```

Open http://localhost:4000/my_site and note:

- The Header and Footer from the layout
- The list element from the page
- The three components rendered with live data assigns
- The zoom in cursor from the stylesheet

Open http://localhost:4000/my_site/blog/my_first_post and note:

- The Header and Footer from the layout
- The path params blog slug
- The live data blog_slug_uppercase
- The zoom in cursor from the stylesheet
