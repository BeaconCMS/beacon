# Installation

Beacon is the core application that loads and renders your site pages. It runs as a library in your Phoenix LiveView application, in this guide we'll start from zero initilizating a new Phoenix LiveView application, installing Beacon, and adding a new site.

## TLDR

We recommend following the guide thoroughly, but if you want a short version or to just recap the main steps:

1. Install Elixir v1.13 or later.

2. Install Phoenix v1.7 or later.

  ```sh
  mix archive.install hex phx_new
  ```

3. Setup a database

4. Generate a new Phoenix application

  ```sh
  mix phx.new --install my_app
  ```

5. Install `:floki` dependency in all environments, change it to:

  ```elixir
  {:floki, ">= 0.30.0"}
  ```

6. Add `:beacon` dependency to `mix.exs`

  ```elixir
  {:beacon, github: "BeaconCMS/beacon", override: true}
  ```

Note that the option `override: true` is required if running Beacon and Beacon LiveAdmin in the same application.

7. Add `:beacon` into `:import_deps` in file `.formatter.exs`

8. Install deps

  ```sh
  mix deps.get
  ```

## Detailed instructions

### Elixir 1.13 or later

The minimum required version to run Beacon is Elixir v1.13. Make sure you have at least that version installed along with Hex:

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

Beacon also requires at least Phoenix v1.7 to work properly, make sure you have the latest `phx_new` archive - the command to generate new Phoenix applications.

```sh
mix archive.install hex phx_new
```

### Database

Beacon supports [PostgresSQL](https://www.postgresql.org). Make sure a PostgreSQL server is running and you have the necessary credentials to create a new database.

### Generate a new application

We'll be using `phx_new` to generate a new application. You can run `mix help phx.new` to show the full documentation with more options, but let's use the default config for our new site. Execute:

```sh
mix phx.new --install my_app
```

Or if you prefer an Umbrella application, execute:

```sh
mix phx.new --umbrella --install my_app
```

Beacon supports both.

After it finishes you can open the generated directory: `cd my_app`

### Install Beacon

1. Edit `mix.exs` to install `:floki` in all environments, change it to:

```elixir
{:floki, ">= 0.30.0"}
```

2. Still in `mix.exs`, add `:beacon` as a dependency:

```elixir
{:beacon, github: "BeaconCMS/beacon", override: true}
```

Or add to both apps `my_app` and `my_app_web` if running in an Umbrella app.

Note that the option `override: true` is required if running Beacon and Beacon LiveAdmin in the same application.

3. Add `:beacon` to `import_deps` in the `.formatter.exs` file:

```elixir
[
  import_deps: [:ecto, :ecto_sql, :phoenix, :beacon],
  # rest of file ommited
]
```

4. Run `mix deps.get`