# Changelog

## 0.1.0-rc.0

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
  * Pages
    * Pre-defined default home page
  * Snippets to render small reusable templates
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