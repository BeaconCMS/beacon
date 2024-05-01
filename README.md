# Beacon

> Performance without compromising productivity.

Beacon is a content management system (CMS) built with Phoenix LiveView. It brings the rendering speed benefits of Phoenix to even the most content-heavy pages with faster render times to boost SEO performance.

## Guides

Check out the [guides](https://github.com/BeaconCMS/beacon/tree/main/guides) to get started:

* [Installation](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/installation.md) to get your first site up and running
* [Deployment on Fly.io](https://github.com/BeaconCMS/beacon/blob/main/guides/deployment/fly.md) to deploy your site on Fly.io

## Demo

A sample application running latest Beacon is available at https://github.com/BeaconCMS/beacon_demo

## Status

Pre-release version. You can expect incomplete features and breaking changes before a stable v0.1.0 is released.

Main components:
- Core - A functional website can be built and deployed by inserting components in database and running a server, see https://github.com/BeaconCMS/beacon_demo
- Admin - LiveView UI to manage layouts, pages, and all other resources. See https://github.com/BeaconCMS/beacon_live_admin
- Page Builder - An easy to use, drag & drop UI for building pages, targeted to non-technical users. In the initial stages of development.

## Contributing

Check out the [CONTRIBUTING.md](https://github.com/BeaconCMS/beacon/blob/main/CONTRIBUTING.md) doc for overall guidelines to contribute to this project,
then follow the [Local Development](https://github.com/BeaconCMS/beacon#local-development) steps to run a local project or watch the video below to understand more
about Beacon internals:

<a href="https://www.youtube.com/watch?v=5jk0fIJOFuc">
  <img src="https://raw.githubusercontent.com/BeaconCMS/beacon/main/assets/images/youtube_card.png" width="512" alt="YouTube card - ElixirConf 2023 - Leandro Pereira - Beacon: The next generation of CMS in Phoenix LiveView">
</a>

## Local Development

The file `dev.exs` is a self-contained Phoenix application running Beacon with sample data and code reloading enabled. Follow these steps to get a site up and running:

1. Install dependencies, build assets, and run database setup:

```sh
mix setup
```

If deps compilation fails, make sure your environment has the compilers installed.
On Ubuntu look for the `build_essential` package, on macOS install utilities with `xcode-select --install`

2. Execute the dev script:

```sh
iex --sname core -S mix dev
```

Note that running a named node isn't required unless you're running Beacon LiveAdmin too.

Finally, visit any of the routes defined in `dev.exs`, eg: http://localhost:4001/dev or http://localhost:4001/dev/sample

## Looking for help with your Elixir project?

<img src="assets/images/dockyard_logo.png" width="256" alt="DockYard logo">

At DockYard we are [ready to help you build your next Elixir project](https://dockyard.com/phoenix-consulting).
We have a unique expertise in Elixir and Phoenix development that is unmatched and we love to [write about Elixir](https://dockyard.com/blog/categories/elixir).

Have a project in mind? [Get in touch](https://dockyard.com/contact/hire-us)!
