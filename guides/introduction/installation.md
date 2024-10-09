# Installation

## Objective

Install Beacon and Beacon LiveAdmin in a new Phoenix LiveView application to enable running and managing sites.

## Notes

- If you already have a Phoenix LiveView application that meets the minimum requirements for Beacon and Beacon LiveAdmin, you can skip to step 6.
- Beacon LiveAdmin can be installed in a separated application in a cluster environment but such advanced setup is not covered in this guide.

## Steps

1. Install Elixir v1.14 or later

Check out the official [Elixir install guide](https://elixir-lang.org/install.html) for more info.

2. Update Hex

  ```sh
  mix local.hex
  ```

If that command fails or Elixir version is outdated, please follow the [Elixir Install guide](https://elixir-lang.org/install.html) to set up your environment correctly.

3. Install Phoenix v1.7 or later

  ```sh
  mix archive.install hex phx_new
  ```

Check out the official [Phoenix install guide](https://hexdocs.pm/phoenix/installation.html) for more info.

4. Setup a PostgreSQL database

We recommend using PostgreSQL that's officially supported, make sure it's [installed and running](https://wiki.postgresql.org/wiki/Detailed_installation_guides).

5. Generate a new Phoenix application

  ```sh
  mix phx.new --install my_app
  ```

Note that Beacon supports Umbrella applications as well.

6. Change the existing `:floki` dependency to make it available in all environments

  ```diff
  - {:floki, ">= 0.30.0", only: :test},
  + {:floki, ">= 0.30.0"},
  ```

7. Add `:beacon` and `:beacon_live_admin` dependencies to `mix.exs`

  ```diff
  + {:beacon, "~> 0.1.0", override: true},
  + {:beacon_live_admin, ">= 0.0.0"},
  ```

8. Add `:beacon` and `:beacon_live_admin` into `:import_deps` in file `.formatter.exs`

  ```diff
  - import_deps: [:ecto, :ecto_sql, :phoenix],
  + import_deps: [:ecto, :ecto_sql, :phoenix, :beacon, :beacon_live_admin],
  ```

9. Install deps

  ```sh
  mix deps.get
  ```

## Next Steps

Beacon is installed but you have no sites yet. Follow the [Your First Site](your-first-site.md) guide to setup one and get familiar with Beacon.
