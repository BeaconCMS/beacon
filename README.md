# Beacon

> Performance without compromising productivity.

Beacon is a content management system (CMS) built with Phoenix LiveView. It brings the rendering speed benefits of Phoenix to even the most content-heavy pages with faster render times to boost SEO performance.

## Guides

Check out the [guides](https://github.com/BeaconCMS/beacon/tree/main/guides) to get started:

* [Installation](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/installation.md) to get your first site up and running
* [Admin](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/admin.md) to enable the Admin UI
* [API](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/api.md) to enable the Beacon API
* [Deployment on Fly.io](https://github.com/BeaconCMS/beacon/blob/main/guides/deployment/fly.md) to deploy your site on Fly.io

## Demo

A sample application running latest Beacon is available at https://github.com/BeaconCMS/beacon_demo

## Status

Pre-release version. You can expect incomplete features and breaking changes before a stable v0.1.0 is released.

Main components:
- Core - A functional website can be built and deployed by inserting components in database and running a server, see https://github.com/BeaconCMS/beacon_demo
- Admin - UI to manage pages and assets. Under heavy development.
- Page Builder - An easy to use, drag & drop UI for building pages, targeted to non-technical users. Not released yet, in the initial stages of development.

## Local Development

The file `dev.exs` is a self-contained Phoenix application running Beacon with sample data and code reloading enabled.

Install [cmark-gfm](https://github.com/github/cmark-gfm) and execute the following to get a local server running:

```sh
mix setup
iex -S mix dev
```
