# Roadmap

Planned work for Beacon and related projects.

The issues tagged as `roadmap` in [beacon](https://github.com/BeaconCMS/beacon/labels/roadmap) and [beacon_live_admin](https://github.com/BeaconCMS/beacon_live_admin/labels/roadmap)
refer to issues that solve items in this roadmap. They have priority over others and will be included in the next releases.

The priority is defined by demand, added value to the project, and [contributions](CONTRIBUTING.md). But we also reserve the right to change this roadmap
at any time to reflect changes in the project or the community as we learn more and grow.

"Resources" in this document refers to resources managed by Beacon, such as pages, layouts, components, live data, media assets, and more.

## Adoption
- Provide more guides and recipes as we learn more about what the community needs
- Make code documentation part of the development process
- Update the content of https://beaconcms.org
- Add support for more LiveView resources like JS hooks
- Admin interactive tour for user onboarding

## Content Creation Experience

#### Visual Editor
- High-level visual controls that generate the underlyng styles, effects, and attributes in general. Including bot not limited to:
  - colors
  - sizing
  - positioning
  - shadows
  - visibility
  - navigation (links)
  - eex (:if conditionals for example)
  - animiations
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
- Expose built-in components and colors to allow users build custom pages easily

## Tooling, Integration, and Extensibility

#### Resource Loading
  - Make use of `:error_handler` to load modules dynamicaly on-the-fly
  - Introduce a lock to control module compilation and avoid race conditions

### Plugin System
  - Load at runtime
  - Refresh site config at runtime
  - Define the behaviour and config of plugins
  - Migrate and rollback data
  - Start new plugin projects with Igniter
  - Preview and reload on development
  - Expand existing hooks to allow modifying more parts of Beacon internal lifecycle
  - Create a Plausible plugin
  - Extract Media Library S3 Provider into a plugin

### CLI and Local Environment
  - Fetch resources from running sites
  - Upload local resources to running sites
  - Generate new Phoenix projects with Beacon or install Beacon in single and umbrella apps with an Igniter task
  - Igniter task to generate new sites and resources

### Integration with host Phoenix app
  - Support Windows
  - Support other major database vendors as MySQL, MSSQL, and SQLite
  - Introduce Beacon.Test to help test resources and lifecycles
  - Reuse some resources between the host app and Beacon, such as components and stylesheets.

### SEO
- Redirect manager to handle deleted pages and broken links
- Tool to search the top Google search results and compare the terms used in your site - https://x.com/ac_alejos/status/1774171644090544627

### General
- Create, change, and load new sites at runtime on the admin interface
- Release Components as plugins to quickly bootstrap new pages and serve as example
- LiveView Native integration
- Support Tailwind v4
- Localization