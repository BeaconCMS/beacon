# Beacon CMS — Template Type System Design

## Problem

Beacon currently hardcodes content-type-specific logic into its core: `author_id`, `faq_items`, `page_type`, Article/FAQPage/Person JSON-LD auto-generation, and blog-specific admin UI. This makes Beacon unsuitable for non-blog use cases without forking, and it conflates platform concerns with content-type concerns.

## Solution

A **template type** system that allows Beacon admins to define content type schemas at runtime. Template types formalize the data contract for a class of pages: what fields they expect, how those fields map to JSON-LD structured data, and how they map to meta tags.

## Core Principles

1. **Template types are optional.** Pages without a template type work exactly as they do today.
2. **Everything is a page.** Template type instances (blog posts, author profiles, products) are all pages in `beacon_pages`. No separate entity tables.
3. **Template types are data contracts, not visual templates.** They define what data a page expects, not how it looks. The page's template (Beacon syntax) handles rendering.
4. **No hardcoded content types in core.** Article, FAQ, Author, Product are all template types that admins create — not baked into the platform.
5. **Two-tier data interpolation is orthogonal.** Template syntax decides whether data resolves at Beacon-runtime (`{{ datasource.path }}`) or client-runtime (`{{ @path }}`). Template types don't dictate the tier.

## Administrative Tiers

### Global Template Types
- Created by **Beacon-level admins** (not scoped to any site).
- Available to **all sites** on the Beacon instance.
- `site` field is `nil` in the database.
- Examples: "Blog Post", "Author Profile", "Product Page", "FAQ Page".

### Site-Specific Template Types
- Created by **site-level admins** through LiveAdmin.
- Available only to **that site**.
- `site` field is set to the site atom.
- Examples: "Case Study", "Press Release", "Job Posting", "Recipe".

A site sees global template types plus its own site-specific ones when assigning a template type to a page.

## Data Model

### `beacon_template_types` Table

```sql
CREATE TABLE beacon_template_types (
  id          BINARY_ID PRIMARY KEY,
  site        TEXT,                    -- NULL for global, site atom for site-specific
  name        TEXT NOT NULL,           -- "Blog Post"
  slug        TEXT NOT NULL,           -- "blog-post"

  -- Field definitions: what data this template type expects
  field_definitions JSONB NOT NULL DEFAULT '[]',

  -- Declarative JSON-LD mapping
  json_ld_mapping JSONB DEFAULT '{}',

  -- Declarative meta tag mapping
  meta_tag_mapping JSONB DEFAULT '{}',

  inserted_at TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ,

  UNIQUE(site, slug)  -- unique per site (or globally when site is NULL)
);
```

### Page Changes

```sql
ALTER TABLE beacon_pages ADD COLUMN template_type_id BINARY_ID
  REFERENCES beacon_template_types(id) ON DELETE SET NULL;

ALTER TABLE beacon_pages ADD COLUMN fields JSONB DEFAULT '{}';

-- Same for snapshots
ALTER TABLE beacon_page_snapshots ADD COLUMN template_type_id BINARY_ID;
ALTER TABLE beacon_page_snapshots ADD COLUMN fields JSONB DEFAULT '{}';
```

- `template_type_id`: optional FK linking a page to its template type. `NULL` means a plain page (no template type).
- `fields`: structured JSONB data governed by the template type's `field_definitions`. Validated at changeset time against the definition.

### What Gets Removed from Page Schema

These hardcoded fields are removed because they belong to template type definitions, not the core Page schema:

- `author_id` — becomes a reference field on the "Blog Post" template type
- `faq_items` — becomes a structured field on the "FAQ Page" template type
- `page_type` — replaced by the template type's JSON-LD mapping (which declares `@type`)

`date_modified` stays — it's universal content freshness, not content-type-specific.

## Field Definitions

Each template type declares an array of field definitions:

```json
[
  {
    "name": "author",
    "label": "Author",
    "type": "reference",
    "reference_template_type": "author-profile",
    "required": true,
    "description": "The page author"
  },
  {
    "name": "published_date",
    "label": "Published Date",
    "type": "datetime",
    "required": true
  },
  {
    "name": "excerpt",
    "label": "Excerpt",
    "type": "text",
    "required": false,
    "max_length": 300
  },
  {
    "name": "illustration",
    "label": "Featured Image",
    "type": "url",
    "required": false
  },
  {
    "name": "tags",
    "label": "Tags",
    "type": "list",
    "item_type": "string"
  }
]
```

### Supported Field Types

| Type | Description | Storage in JSONB |
|------|-------------|-----------------|
| `string` | Short text (single line) | `"value"` |
| `text` | Long text (multi-line) | `"value"` |
| `integer` | Whole number | `123` |
| `decimal` | Decimal number | `"19.99"` (string to preserve precision) |
| `boolean` | True/false | `true` / `false` |
| `datetime` | ISO 8601 datetime | `"2026-04-13T10:30:00Z"` |
| `date` | ISO 8601 date | `"2026-04-13"` |
| `url` | URL string | `"https://..."` |
| `select` | Enum from predefined options | `"option_value"` |
| `list` | Array of values | `["a", "b", "c"]` |
| `reference` | Page ID referencing another page (with a specific template type) | `"uuid-of-referenced-page"` |

### Reference Fields

A reference field (`type: "reference"`) stores the `id` of another page. The `reference_template_type` property specifies which template type the referenced page should have (e.g., an "author" field references an "Author Profile" page).

Reference resolution is **data-source driven**. Beacon does NOT auto-resolve references. The site's GraphQL data source is responsible for fetching related data. The template author writes the appropriate data bindings in the template syntax.

## JSON-LD Mapping

The template type's `json_ld_mapping` is a declarative JSON structure with field references:

```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "{title}",
  "description": "{fields.excerpt}",
  "datePublished": "{fields.published_date}",
  "image": "{fields.illustration}",
  "author": {
    "@type": "Person",
    "name": "{fields.author.fields.name}",
    "url": "{fields.author.path}"
  }
}
```

### Resolution Rules

- `{title}` — resolves to the page's title field
- `{path}` — resolves to the page's path
- `{description}` — resolves to the page's description field
- `{canonical_url}` — resolves to the page's canonical URL
- `{fields.X}` — resolves to the page's `fields["X"]` value
- `{fields.X.fields.Y}` — resolves to the referenced page's `fields["Y"]` value (requires the data source to have provided the resolved data)
- `{fields.X.path}` — resolves to the referenced page's path

At render time, Beacon walks the JSON-LD mapping, resolves all `{...}` references against the page's data (manifest + GraphQL assigns), and produces the final JSON-LD.

For client-runtime data (`@`-prefixed in the template), JSON-LD resolution depends on where the page is rendered:
- If rendered by Beacon (LiveView): resolved at request time from GraphQL data.
- If rendered by a client SDK: the client is responsible for resolving JSON-LD from its own data and rendering the `<head>`.

## Meta Tag Mapping

Similar declarative structure:

```json
{
  "og:type": "article",
  "og:image": "{fields.illustration}",
  "og:title": "{title}",
  "description": "{fields.excerpt}",
  "article:published_time": "{fields.published_date}",
  "article:author": "{fields.author.fields.name}"
}
```

These meta tags are generated in addition to (and overridden by) any page-level meta tag settings. Priority cascade:

1. Page-level explicit meta tags (highest)
2. Template type meta tag mapping
3. Layout meta tags
4. Site defaults (lowest)

The existing deduplication logic handles conflicts.

## Two-Tier Data Interpolation

Template types are agnostic to the data tier. The template syntax determines resolution:

### Beacon-Runtime (Publish Time)
```html
<h1>{{ dockyard.site_name }}</h1>
<p>{{ dockyard.employee_count }} employees</p>
```
- Prefixed with a named data source (e.g., `dockyard`)
- Beacon queries the named GraphQL endpoint at publish time
- Values baked into the AST as static content
- Used for site-wide data that's the same for all visitors

### Client-Runtime
```html
<h1>{{ @post.title }}</h1>
<p>By {{ @post.author_name }}</p>
<time>{{ @post.published_date }}</time>
```
- Prefixed with `@`
- Left as expression nodes in the AST
- Client SDK compiles the AST and substitutes data from its own source
- Client caches the rendered result with its own TTL
- Used for per-instance data (individual blog posts, product pages)

### Template Type's Role

The template type doesn't dictate which tier a field resolves in. It documents:
- What fields the page expects (names, types, validation)
- How those fields map to JSON-LD and meta tags
- The template author decides the tier by how they write the bindings

## Admin UI

### Beacon-Level Admin: Template Type Manager

A new top-level page in LiveAdmin (or a Beacon-level admin interface):
- List all global template types
- Create/edit global template types
- Field definition editor: add/remove/reorder fields with name, type, required, options
- JSON-LD mapping editor: Monaco/JSON editor with `{field}` reference syntax
- Meta tag mapping editor: key-value editor with `{field}` reference support
- Preview: show what JSON-LD and meta tags would look like for a sample page

### Site-Level Admin: Template Type Manager

Same UI but scoped to a site. Shows both global and site-specific types.
Site admins can create site-specific types but cannot modify global ones.

### Page Editor Changes

When creating or editing a page:
- Template type selector dropdown (optional — "None" for plain pages)
- When a template type is selected, the "Fields" section appears with auto-generated form inputs based on the template type's field definitions
- Reference fields render as page pickers (filtered to the referenced template type)
- The SEO tab shows the resolved JSON-LD preview and meta tag preview based on current field values

## What Gets Removed from Core

### From `beacon_pages` schema:
- `author_id` field and FK
- `faq_items` field
- `page_type` field (replaced by template type's JSON-LD `@type`)

### From `beacon_page_snapshots`:
- Same fields removed

### Modules removed entirely:
- `Beacon.Content.Author` (schema)
- `author_manager_live.ex` in LiveAdmin

### Functions removed from `Beacon.Content`:
- All Author CRUD (create_author, update_author, etc.)
- `resolve_author` in loader

### From `Beacon.SEO.JsonLd`:
- `article_schema/3` — replaced by template type JSON-LD mapping
- `faq_page_schema/1` — replaced by template type JSON-LD mapping
- `person_schema/2` — replaced by template type JSON-LD mapping
- Auto-dispatch in `build/3` for article and FAQ

### From `Beacon.Web.Layouts`:
- `render_faq_section/1`

### From `Beacon.SEO.Metrics`:
- `pages_with_author`, `pages_with_faq`, `pages_article_type` metrics
- Replace with: `pages_with_template_type` (count of pages assigned a template type)

### From migration V011:
- `beacon_authors` table creation
- `author_id` column additions
- `faq_items` column additions

## What Stays in Core

- All universal SEO fields on Page: `meta_description`, `canonical_url`, `robots`, `og_title`, `og_description`, `og_image`, `twitter_card`
- `date_modified` (universal content freshness)
- `raw_schema` (arbitrary JSON-LD for pages without template types)
- `meta_tags` (manual meta tags)
- Meta tag deduplication, title templates, canonical URL auto-generation
- Redirects, AI crawler management, sitemap, IndexNow
- Internal link graph, measurement
- BreadcrumbList, Organization, WebSite JSON-LD (universal, not content-type-specific)

## What Stays in `Beacon.SEO.JsonLd.build/3`

Only universal schemas:
- `breadcrumb_schema/2` — path-based, universal
- `organization_schema/2` — site config, universal
- `website_schema/2` — site config, universal

Template-type-specific JSON-LD is generated by resolving the template type's `json_ld_mapping` — NOT by hardcoded schema builder functions.

## Example: Blog Post Template Type

A Beacon admin would create a global template type:

**Name:** Blog Post
**Slug:** blog-post

**Field Definitions:**
```json
[
  {"name": "author", "type": "reference", "reference_template_type": "author-profile", "required": true},
  {"name": "published_date", "type": "datetime", "required": true},
  {"name": "excerpt", "type": "text", "max_length": 300},
  {"name": "illustration", "type": "url", "label": "Featured Image"},
  {"name": "illustration_alt", "type": "string", "label": "Image Alt Text"},
  {"name": "tags", "type": "list", "item_type": "string"}
]
```

**JSON-LD Mapping:**
```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "{title}",
  "description": "{description}",
  "datePublished": "{fields.published_date}",
  "dateModified": "{date_modified}",
  "image": "{fields.illustration}",
  "url": "{canonical_url}",
  "author": {
    "@type": "Person",
    "name": "{fields.author.fields.name}",
    "jobTitle": "{fields.author.fields.job_title}"
  },
  "publisher": {
    "@type": "Organization",
    "name": "{site_name}"
  }
}
```

**Meta Tag Mapping:**
```json
{
  "og:type": "article",
  "og:image": "{fields.illustration}",
  "article:published_time": "{fields.published_date}",
  "article:author": "{fields.author.fields.name}"
}
```

A page at `/blog/:slug` using this template type would:
1. Have the "Blog Post" template type assigned
2. Have `fields` populated with author reference, published_date, etc.
3. Get Article JSON-LD auto-generated from the mapping
4. Get `og:type: article` and other meta tags from the mapping
5. Use `{{ @post.title }}` in its template for client-runtime substitution

## Migration Path

1. Create `beacon_template_types` table
2. Add `template_type_id` and `fields` to `beacon_pages` and `beacon_page_snapshots`
3. Remove `author_id`, `faq_items`, `page_type` from pages/snapshots
4. Drop `beacon_authors` table
5. Existing pages with `page_type: "article"` would need migration to a Blog Post template type (site-specific migration responsibility)

## Implementation Phases

### Phase 1: Core Schema + CRUD
- `beacon_template_types` table + Ecto schema
- `template_type_id` and `fields` on Page
- Template type CRUD in Content API
- Field validation at changeset time

### Phase 2: JSON-LD + Meta Tag Resolution
- Template type JSON-LD mapping resolver
- Template type meta tag mapping resolver
- Integration into `render_schema/1` and `meta_tags/1`

### Phase 3: Remove Hardcoded Content Types
- Remove author_id, faq_items, page_type from core
- Remove Author schema and CRUD
- Remove article_schema, faq_page_schema, person_schema from JsonLd
- Remove render_faq_section from layouts

### Phase 4: Admin UI
- Template Type Manager (global + site-specific)
- Field definition editor
- JSON-LD mapping editor
- Meta tag mapping editor
- Page editor: template type selector + dynamic fields form
