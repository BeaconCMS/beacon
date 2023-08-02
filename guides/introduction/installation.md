# Installation

Beacon is an application that runs in existing Phoenix LiveView applications. In this guide we'll install all required tools, generate a new Phoenix LiveView application, and install Beacon.

After the installation is done, please follow the guide [Your First Site](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/your_first_site.md) to learn how to setup a functioning site.

## TLDR

We recommend following the guide thoroughly, but if you want a short version or just recap the main steps:

1. Install Elixir v1.14+

2. Install Phoenix v1.7+

  ```sh
  mix archive.install hex phx_new
  ```

3. Install [cmark-gfm](https://github.com/github/cmark-gfm)

_Note this dependency will be removed eventually._

4. Setup a database

5. Generate a new Phoenix application

  ```sh
  mix phx.new --install my_app
  ```

6. Add `:beacon` dependency to `mix.exs`

  ```elixir
  {:beacon, github: "BeaconCMS/beacon", override: true}
  ```
  
7. Change dep `:floki` to remove `only: :test` as:

  ```elixir
  {:floki, ">= 0.30.0"}
  ```

8. Add `:beacon` into `:import_deps` in file `.formatter.exs`

9. Run `mix setup`

## Detailed Instructions

### Elixir 1.14 or later

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

### Phoenix 1.7 or later

Beacon also requires a minimum Phoenix version to work properly, make sure you have the latest `phx_new` archive - the command to generate new Phoenix applications.

```sh
mix archive.install hex phx_new
```

### cmark-gfm

Is the tool used to convert Markdown to HTML. Install it from [https://github.com/github/cmark-gfm](https://github.com/github/cmark-gfm) and make sure the binary `cmark-gfm` is present in your env `$PATH`

_Note this dependency will be removed eventually._

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
{:beacon, github: "BeaconCMS/beacon", override: true},
```

Or add to both apps `my_app` and `my_app_web` if running in an Umbrella app.

2. Change the `:floki` dep to look like:

```elixir
{:floki, ">= 0.30.0"}
```

_Remove `only: :test`_

3. Add `:beacon` to `import_deps` in the .formatter.exs file:

```elixir
[
 import_deps: [:ecto, :ecto_sql, :phoenix, :beacon],
 # rest of file
]
```

4. Run `mix setup`