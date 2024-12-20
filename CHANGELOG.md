# Changelog

## Unreleased

## 0.3.3 (2024-12-13)

### Fixes

  - Support LiveView v1.0.1
  - Fix variant roll changing when fetching assets

## 0.3.2 (2024-12-11)

### Fixes

  - Make the logic to find reachable sites less strict
  - Prevent components module reloading in manual mode

### Doc

  - Add missing instructions on Upgrade Guide v0.3.0 where to place the Beacon tuple

### Chore

  - Exclude Dialyzer files from package

## 0.3.1 (2024-12-10)

### Fixes

  - Avoid unloading imported dynamic Components modules without a replacement

## 0.3.0 (2024-12-05)

### Enhancements
  - Support Phoenix LiveView 1.0
  - Add `Beacon.Plug` in the `:beacon` pipeline
  - Generate sites in the main host app alias to allow mixing routes
  - Introduce global process lock for Loader Workers, preventing multiple workers from
    attempting to compile the same module simultaneously
  - Page Warming - Beacon will now eagerly load a small number of pages (default 10) at boot time for SEO
  - `Beacon.Config` option `:page_warming` can change the number of pages to warm, specify which pages, or disable warming per site
  - Only start reachable sites on boot to save resources
  - Warn when a site defined in the router is not reachable
  - Add `Beacon.Plug` for consistent rendering when using Page Variants
  - `mix beacon.install` now adds `Beacon.Plug` to host app Router

### Fixes
  - Rename arg from `name` to `tag_name` in dynamic_tag component
  - Remove self dependency on ErrorPage module
  - Allow `:admin` source for BeaconAssigns in unpublished Pages

### Chores
  - Isolate dynamic function calls

### Documentation
  - Add Deployment Topologies guide

## 0.2.2 (2024-11-17)

### Fixes
  - Do not duplicate default beacon.webp media asset
  - Load resources on dev.exs script

### Chores
  - Improve `Beacon.apply_mfa/4` error output

## 0.2.1 (2024-11-14)

### Fixes
  - Fix site scoping for media asset path/url
  - Serve media library assets inside aliased scopes
  - Only reset cache and route table for published pages

### Documentation
  - Fix identation on install guide
  - Add upgrade guide from pre-rc to v0.1

### Chores
  - Rename asset URL from `__beacon_assets__` to `__beacon_media__` to avoid conflicts
  - Expose option `:root_layout` in `beacon_site`

## 0.2.0 (2024-11-08)

### Enhancements
  - Introduce `Beacon.ErrorHandler` to load resources and dependencies
  - Add `beacon.gen.tailwind_config` task to generate a custom Tailwind config
  - Add `beacon.gen.site` task to generate new sites
  - Rework `beacon.install` with Igniter to be composable
  - Introduce config `:tailwind_css`

### Documentation
  - Create recipe Protect Pages with Basic Auth
  - Update docs to use the new tasks created with Igniter
  - Update Deploy to Fly.io guide to use a release step to copy files into the release
  - Create recipe Reuse app.css

### Chore
  - Only subscribe to page changes on `:live` sites

## 0.1.4 (2024-10-31)

### Fixes
  - Fix Page and Layout publish on cluster environments
  - Skip dependency `:vix` v0.31.0 due to a bug to open files
  - Fix page title not updating on page patch

### Chores
  - TailwindCompiler - increase timeout to 4 minutes when waiting to generate template files

## 0.1.3 (2024-10-29)

### Enhancements
 - Auto populate Media beacon.webp to be used on components

### Fixes
 - Exclude the node modules from Tailwind content #622 by @anu788
 - Allow to patch (navigate patching the content) to another site

## 0.1.2 (2024-10-23)

### Fixes
  - [Content/Component] - Validate attr opts and slot opts to avoid invalid state and compilation errors

## 0.1.1 (2024-10-22)

### Enhancements
  - Support Phoenix LiveView v1.0.0-rc.7

### Documentation
  - Link to latest version
  - Guide for `on_mount` and `handle_info` - #599 by @djcarpe

## 0.1.0 (2024-10-09)

### Breaking Changes
  - Require minimum Elixir v1.14.0
  - Require minimun `:mdex` v0.2.0
  - Removed config `:skip_boot?` in favor of `:mode` which can be `:live`, `:testing`, and `:manual` (defaults to `:live`) - the major difference between then is that live loads all modules and broadcasts all messages, testing only does that when it makes sense for tests (for example it does reload modules on fixtures), and manual does pretty much nothing, it's useful to seed data or to test specific scenarios where you need total control over Beacon.Loader

### Enhancements
  - Add `Beacon.Test` that provides testing utilities to use on host apps
  - Add `Beacon.Test.Fixtures` to expose fixtures to seed test data, the same used by Beacon itself
  - Reload modules synchronously on `testing` mode
  - Leverage `:manual` mode during boot to avoid unnecessary calls to Tailwind compiler, speeding up the whole process to start sites
  - Enable Markdown options: `:footnotes`, `:multiline_block_quotes`, `:shortcodes` (emojis), `:underline`, `:relaxed_tasklist_matching`, and `:relaxed_autolinks`.
    See https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html and https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html for more info.
  - Added Shared Info Handlers (`info_handle` callbacks) - 578 by @ddink

### Fixes
  - Remove unnecessary `:plug_cowboy` dependency
  - [Heroicons] Namespace the vendorized module as `Beacon.Heroicons` to avoid conflicts

### Documentation
  - Added "Testing" recipe to demonstrate usage of `Beacon.Test`
  - Added guide to customize the Markdown options
  - Added guide on how to embed tweets using the Twitter JS api

## 0.1.0-rc.2 (2024-09-20)

### Breaking Changes
  - Renamed component `.icon` to `.heroicon` to make it explicit that it's rendering Heroicons and also to avoid future conflicts
  - Require minimum Gettext v0.26 to use the new backend module
  - Default `:sort` option value in `Content.list_pages/2` changed from `:title` to `:path`

### Fixes
  - [Components] Bring back the `.icon` (heroicon) component using https://hex.pm/packages/heroicons instead of a Tailwind plugin that depends on the unavailable `fs` API
  - [Media Library] Guard against invalid values for `:sort` option in `MediaLibrary.list_assets/2`
  - [Content] Guard against invalid values for `:sort` option in `Content.list_layouts/2`
  - [Content] Guard against invalid values for `:sort` option in `Content.list_pages/2`
  - [HEEx Decoder] Handle attr values with `nil` values, for example the `defer` in script tags

### Documentation
  - Updated Heroicons recipes to reflect changes on configuration and naming

## 0.1.0-rc.1 (2024-08-27)

### Enhancements
  - Added Shared Event Handlers which are global event handlers shared among all pages.
    That's a simple model to work with where a layout, component, or multiple pages may share the same event handler,
    for example a newsletter subscription form in a component called in a layout doesn't need to duplicate the same
    event handler in all pages.

### Breaking Changes
  - Removed Page Event Handlers in favor of Shared Event Handlers.
    With Shared Event Handlers, it doesn't make sense to have page event handlers unless overriding becomes a neccessity.
    The data is automatically migrated in a best-effort way, duplicated event handler names (from multiple pages) are
    consolidated into a single shared event handler. See the migration `V002` for more info.
  - Removed "page event handlers" in `Content` API in favor of "event handlers" (removed the prefix `page`),
    for example: `update_event_handler_for_page -> create_event_handler` and `change_page_event_handler -> change_event_handler`.

## Fixes
  - Display parsed page title on live renders

## 0.1.0-rc.0 (2024-08-02)

### Enhancements
  - Loader to fetch resources from DB and compile modules
  - Media Library to upload and serve images and other media
    - Built-in Repo (DB) and S3 storage
    - Post-process images to optimized .webp format
  - Error Page to handle failures and display custom pages
    - Pre-defined 404 and 500 pages
  - Components
    - Pre-defined set of default components
    - Support attrs and slots
    - Support for Elixir and HEEx parts
  - Layouts
    - Pre-defined default layout
    - Meta tags
    - Resource links
    - Revisions
  - Pages
    - Pre-defined default home page
    - Meta tags
    - Schema.org support
    - Events (handle_event)
    - Revisions
  - Snippets (liquid template)
    - Page title
    - Meta tags
  - Stylesheets
  - Live Data to define and manage assigns at runtime
    - Support Elixir and text content
  - Custom Page fields to extend the Page schema
  - Router helper `~p` to generate paths with site prefixes
  - Content management through the `Beacon.Content` API
  - A/B Variants
  - TailwindCSS compiler
  - `@beacon` read-only assign
  - mix task `beacon.install` to bootstrap a new Beacon site
  - Lifecycle hooks to inject custom logic into multiple layers of the process
