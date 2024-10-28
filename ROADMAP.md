# Roadmap

Planned work for Beacon and related projects.

The issues tagged as `roadmap` in [beacon](https://github.com/BeaconCMS/beacon/labels/roadmap) and [beacon_live_admin](https://github.com/BeaconCMS/beacon_live_admin/labels/roadmap)
refer to issues that solve items in this roadmap. They have priority over others and will be included in the next releases.

The priority is defined by demand, added value to the project, [contributions](CONTRIBUTING.md), and internal prioritization by the core team and DockYard.
We reserve the right to change this roadmap at any time to reflect changes in the project or the community as we learn more and grow, and to update it
as items are completed.

"Resources" in this document refers to resources managed by Beacon, such as pages, layouts, components, live data, media assets, and more.

## Adoption
- Provide more guides and recipes as we learn more about what the community needs
- Make code documentation part of the development process
- Update the content of https://beaconcms.org
- Add support for more Phoenix and LiveView resources such as JS hooks
- Admin interactive tour for user onboarding

## Content Creation Experience

#### Visual Editor
- High-level visual controls that generate the underlying styles, effects, and attributes in general. Including but not limited to:
  - colors
  - sizing
  - positioning
  - shadows
  - visibility
  - navigation (links)
  - eex (:if conditionals for example)
  - animations
- Breakpoints manager to build responsive designs
- Typography system to load and preview custom fonts
- Enable the visual editor on Components and Layouts editors
- Inline links in the preview to jump to pages, layouts, components, and media assets

#### Code Editor
- Rich Markdown editor that provides high-level visual controls to upload media assets, create page links, embed Phoenix components, and more.

#### Media Library
- Redesign Media Library - https://www.figma.com/design/k8NhxbRRb8hm4fc1RQHms1/Media-Library?node-id=30-57434

#### Admin Interface
- Adopt a component/UI library to improve the standard look and feel of admin pages
- Expose built-in components and colors to allow users to build custom pages easily

## Tooling, Integration, and Extensibility

#### Resource Loading
  - Make use of `:error_handler` to load modules dynamicaly on-the-fly
  - Introduce a lock to control module compilation and avoid race conditions

#### Plugin and Theme System
  - Packaging and distribution
  - Package structure of files and directories
  - Metadata files plugin.exs and theme.exs to define config and behavior
  - Igniter task to bootstrap new packages
  - API to expose and expand hooks, helpers, and components to modify Beacon internal lifecycle
  - Download and load at runtime
  - Refresh site config at runtime
  - Migrate and rollback data
  - Preview and reload on development
  - Create a Plausible plugin
  - Extract Media Library S3 Provider into a plugin

#### CLI and Local Environment
  - Fetch resources from running sites
  - Upload local resources to running sites
  - Generate new Phoenix projects with Beacon or install Beacon in single and umbrella apps with an Igniter task
  - Igniter task to generate new sites and resources

#### Integration with host Phoenix app
  - Support Windows
  - Support other major database vendors as MySQL, MSSQL, and SQLite
  - Introduce Beacon.Test to help test resources and lifecycles
  - Reuse some resources between the host app and Beacon, such as components and stylesheets.

#### SEO
- Redirect manager to handle deleted pages and broken links
- Smart tools to improve content, eg: https://x.com/ac_alejos/status/1774171644090544627
- Built-in tools to manaage content as sitemaps and feeds.

#### General
- Create, change, and load new sites at runtime on the admin interface
- Release Components as plugins to quickly bootstrap new pages and serve as example
- LiveView Native integration
- Support Tailwind v4
- Localization
