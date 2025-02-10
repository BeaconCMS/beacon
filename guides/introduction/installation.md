# Installation

## Objective

Install Beacon and Beacon LiveAdmin in a new Phoenix LiveView application to enable running and managing sites.

## Notes

- If you already have a Phoenix LiveView application that meets the minimum requirements for Beacon and Beacon LiveAdmin, you can skip to "Install in an existing application".
- Beacon LiveAdmin can be installed in a separate application in a cluster environment but such advanced setup is not covered in this guide.

## Steps

1. Setup a PostgreSQL database server

Make sure it's [installed and running](https://wiki.postgresql.org/wiki/Detailed_installation_guides).

Currently, only PostgreSQL is supported.

2. Install Elixir v1.14 or later

Check out the official [Elixir install guide](https://elixir-lang.org/install.html) for more info.

3. Either install as a new application or add into an existing application

Firstly update Hex:

```sh
mix local.hex
```

Then install or update Phoenix and Igniter Installers

```sh
mix archive.install hex phx_new
mix archive.install hex igniter_new
```

Now choose one of the methods below:

### Install as a new application

If you're starting a new project, you can follow these steps to generate a new Phoenix application with Beacon and Beacon LiveAdmin installed.

Run the following to generate a new app:

```sh
mix igniter.new my_app --install beacon,beacon_live_admin --with phx.new
```

Replace `my_app` with the name of your application and follow the prompts.

### Install in an existing application

Run the following to install Beacon and Beacon LiveAdmin in an existing Phoenix application.

```sh
mix igniter.install beacon,beacon_live_admin
```

## Next Steps

Beacon is installed but you have no sites yet. Follow the [Your First Site](your-first-site.md) guide to set up one and get familiar with Beacon.
