# Roadmap

Planned work for Beacon and BeaconLiveAdmin

See current issues tagged as `roadmap` on [beacon](https://github.com/BeaconCMS/beacon/labels/roadmap) and [beacon_live_admin](https://github.com/BeaconCMS/beacon_live_admin/labels/roadmap).
Those issues have priority over the rest and will be included in the next releases.

## Adoption
- Provide more guides and recipes as we learn more about what the community needs
- Make code documentation part of the development process
- Update https://beaconcms.org

## Content Creation Experience

#### Visual Editor
- High-level visual controls to edit styles, effects, and attributes in general. Including bot not limited to:
  - colors
  - sizing
  - positioning
  - shadows
  - visibility
  - navigation (links)
  - eex (:if conditionals for example)
  - and more
- Breakpoints manager and preview
- Typography to load and preview custom fonts
- Enable the visual editor on Components and Layouts
- Inline links to edit pages and media assets

#### Code Editor
- Rich Markdown editor that provides high-level visual controls to upload media assets, create page links, and more.

#### Media Library
- Redesign Media Library - https://www.figma.com/design/k8NhxbRRb8hm4fc1RQHms1/Media-Library?node-id=30-57434

### Admin Interface
- Adopt a set of standard components and colors on built-in pages
- Expose built-in components and colors to build custom pages

## Tooling, Integration, and Extensibility

### Optimize the Loader process
  - Load dependent modules lazily
  - Introduce a lock to control module compilation
### Introduce a Plugin system to extend and change Beacon behavior and data
  - Load at runtime
  - Refresh site config at runtime
  - Define the behaviour of plugin modules
  - Migrate data
  - Bootstrap using a mix task, potentially using Igniter
  - Preview and reload on development
  - Extract AWS Provider into a plugin
  - Create a Plausible plugin
### Better integration between Beacon and your existing Phoenix app
  - Remove limitations of current mix tasks to install and add new sites to existing apps, potentially using Igniter
  - Introduce Beacon.Test to help test resources and lifecycles
### General
- Built-in SEO tools
- Create, change, and load new sites at runtime on the admin interface
- Release Components as plugins to quickly bootstrap new pages and serve as example
- LiveView Native integration
- Support Tailwind v4
- Localization