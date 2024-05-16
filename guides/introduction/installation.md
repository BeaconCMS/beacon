# Installation

Beacon is the core application that loads and renders your site pages. It runs as a library in your Phoenix LiveView application, in this guide we'll start from zero initilizating a new Phoenix LiveView application, installing Beacon, and adding a new site.

To create the resources for your site, you'll need an admin interface that can be installed following the [Beacon LiveAdmin installation guide](https://github.com/BeaconCMS/beacon_live_admin/blob/main/guides/introduction/installation.md).

We also have prepared the guide [Your First Site](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/your_first_site.md) to get started into creating the first layout, pages, and components for your site.

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

5. Add `:beacon` dependency to `mix.exs`

  ```elixir
  {:beacon, github: "BeaconCMS/beacon", override: true}
  ```

Note that the option `override: true` is required if running Beacon and Beacon LiveAdmin in the same application.

6. Add `:beacon` into `:import_deps` in file `.formatter.exs`

7. Run `mix setup`

Now you can follow the other guides to [install Beacon LiveAdmin](https://github.com/BeaconCMS/beacon_live_admin/blob/main/guides/introduction/installation.md) or create [your first site](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/your_first_site.md).

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

[PostgresSQL](https://www.postgresql.org) is the default database used by Beacon but it also supports MySQL and SQLServer through [ecto adapters](https://github.com/elixir-ecto/ecto#usage). Make sure one of them is up and running in your environment.

### Generate a new application

We'll be using `phx_new` to generate a new application. You can run `mix help phx.new` to show the full documentation with more options, but let's use the default values for our new site:

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

1. Edit `mix.exs` to add `:beacon` as a dependency:

```elixir
{:beacon, github: "BeaconCMS/beacon", override: true}
```

Or add to both apps `my_app` and `my_app_web` if running in an Umbrella app.

Note that the option `override: true` is required if running Beacon and Beacon LiveAdmin in the same application.

2. Add `:beacon` to `import_deps` in the .formatter.exs file:

```elixir
[
  import_deps: [:ecto, :ecto_sql, :phoenix, :beacon],
  # rest of file ommited
]
```

3. Run `mix setup`