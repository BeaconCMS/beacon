# Changelog

## 0.1.0-dev

### Breaking Changes
  * Require minimum Elixir v1.14

### Enhancements
  * Enable Markdown options: `:footnotes`, `:description_lists`, `:multiline_block_quotes`, `:shortcodes` (emojis), `:underline`, `:escape`, `:relaxed_tasklist_matching`, and `:relaxed_autolinks`.
    See https://docs.rs/comrak/latest/comrak/struct.ExtensionOptions.html and https://docs.rs/comrak/latest/comrak/struct.ParseOptions.html for more info.
  * Added Shared Info Handlers (`info_handle` callbacks) - [#578](https://github.com/BeaconCMS/beacon/pull/578) by [@ddink](https://github.com/ddink)

### Fixes
  * [Heroicons] Namespace the vendorized module as `Beacon.Heroicons` to avoid conflicts

### Breaking Changes
  * Require minimun `:mdex` v0.1.17

### Documentation
  * Added guide to customize the Markdown options
  * Added guide on how to embed tweets using the Twitter JS api

## 0.1.0-rc.2 (2024-09-20)

### Breaking Changes
  * Renamed component `.icon` to `.heroicon` to make it explicit that it's rendering Heroicons and also to avoid future conflicts
  * Require minimum Gettext v0.26 to use the new backend module
  * Default `:sort` option value in `Content.list_pages/2` changed from `:title` to `:path`

### Fixes
  * [Components] Bring back the `.icon` (heroicon) component using https://hex.pm/packages/heroicons instead of a Tailwind plugin that depends on the unavailable `fs` API
  * [Media Library] Guard against invalid values for `:sort` option in `MediaLibrary.list_assets/2`
  * [Content] Guard against invalid values for `:sort` option in `Content.list_layouts/2`
  * [Content] Guard against invalid values for `:sort` option in `Content.list_pages/2`
  * [HEEx Decoder] Handle attr values with `nil` values, for example the `defer` in script tags

### Documentation
  * Updated Heroicons recipes to reflect changes on configuration and naming

## 0.1.0-rc.1 (2024-08-27)

### Enhancements
  * Added Shared Event Handlers which are global event handlers shared among all pages.
    That's a simple model to work with where a layout, component, or multiple pages may share the same event handler,
    for example a newsletter subscription form in a component called in a layout doesn't need to duplicate the same
    event handler in all pages.

### Breaking Changes
  * Removed Page Event Handlers in favor of Shared Event Handlers.
    With Shared Event Handlers, it doesn't make sense to have page event handlers unless overriding becomes a neccessity.
    The data is automatically migrated in a best-effort way, duplicated event handler names (from multiple pages) are
    consolidated into a single shared event handler. See the migration `V002` for more info.
  * Removed "page event handlers" in `Content` API in favor of "event handlers" (removed the prefix `page`),
    for example: `update_event_handler_for_page -> create_event_handler` and `change_page_event_handler -> change_event_handler`.

## Fixes
  * Display parsed page title on live renders

## 0.1.0-rc.0 (2024-08-02)

### Enhancements
  * Loader to fetch resources from DB and compile modules
  * Media Library to upload and serve images and other media
    * Built-in Repo (DB) and S3 storage
    * Post-process images to optimized .webp format
  * Error Page to handle failures and display custom pages
    * Pre-defined 404 and 500 pages
  * Components
    * Pre-defined set of default components
    * Support attrs and slots
    * Support for Elixir and HEEx parts
  * Layouts
    * Pre-defined default layout
    * Meta tags
    * Resource links
    * Revisions
  * Pages
    * Pre-defined default home page
    * Meta tags
    * Schema.org support
    * Events (handle_event)
    * Revisions
  * Snippets (liquid template)
    * Page title
    * Meta tags
  * Stylesheets
  * Live Data to define and manage assigns at runtime
    * Support Elixir and text content
  * Custom Page fields to extend the Page schema
  * Router helper `~p` to generate paths with site prefixes
  * Content management through the `Beacon.Content` API
  * A/B Variants
  * TailwindCSS compiler
  * `@beacon` read-only assign
  * mix task `beacon.install` to bootstrap a new Beacon site
  * Lifecycle hooks to inject custom logic into multiple layers of the process
