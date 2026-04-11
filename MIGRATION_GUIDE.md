# Migration Guide

This guide covers breaking changes in Beacon that require action in host applications. Each section includes the migration needed to update your database and templates.

---

## Upgrading to 0.6.0

### Deprecated assigns removed

The following deprecated assigns have been removed from `Beacon.Web.PageLive` and `Beacon.Template`:

| Removed | Replacement |
|---------|-------------|
| `@beacon_live_data[:key]` | `@key` (live data keys are spread as top-level assigns) |
| `@beacon_live_data.key` | `@key` |
| `@beacon_live_data["key"]` | `@key` |
| `@beacon_path_params` | `@beacon.path_params` |
| `@beacon_query_params` | `@beacon.query_params` |

These assigns were duplicates — `@beacon_live_data` was a full copy of data already available as individual assigns (spread via `Component.assign(live_data)`), and `@beacon_path_params` / `@beacon_query_params` duplicated values already nested under `@beacon`.

#### How the data moved

`Component.assign(live_data)` spreads the live data map into top-level assigns. If your live data returns `%{filter: "all", pagination: %{...}}`, then `@filter` and `@pagination` are available directly.

**Important semantic difference for layouts:** Bracket access on a map (`@beacon_live_data[:key]`) returns `nil` for missing keys, while `@key` raises `KeyError`. This matters in **layouts** because layouts wrap all pages but not every page defines every live data key. In layouts, use `assigns[:key]` instead of `@key` for live data references to preserve nil-on-missing safety.

| Context | Pattern | Replacement | Why |
|---------|---------|-------------|-----|
| Page templates | `@beacon_live_data[:key]` | `@key` | Page's own live data defines the key |
| Page templates | `@beacon_live_data.key` | `@key` | Same — key always exists |
| Layouts | `@beacon_live_data[:key]` | `assigns[:key]` | Key may not exist for every page |
| Layouts | `@beacon_live_data.key` | `assigns[:key]` | Same — use nil-safe access in layouts |

#### Required migration

Create a **single** migration in your host application that updates all stored templates (drafts and published snapshots). This migration handles all access patterns including Elixir identifiers with trailing `?` or `!` characters, and fixes layouts to use nil-safe `assigns[:key]` access.

```elixir
defmodule MyApp.Repo.Migrations.BeaconUpgradeTo060 do
  @moduledoc false
  use Ecto.Migration

  import Ecto.Query

  @targets [
    {"beacon_pages", "template"},
    {"beacon_layouts", "template"},
    {"beacon_error_pages", "template"},
    {"beacon_components", "template"},
    {"beacon_components", "body"},
    {"beacon_snippet_helpers", "body"},
    {"beacon_event_handlers", "code"},
    {"beacon_info_handlers", "code"},
    {"beacon_live_data_assigns", "value"}
  ]

  def up do
    # Phase 1: Replace deprecated assigns in all draft/source tables
    for {table, column} <- @targets do
      # @beacon_live_data[:key] or @beacon_live_data[:key?] → @key / @key?
      execute """
      UPDATE #{table}
      SET #{column} = regexp_replace(
        #{column},
        '@beacon_live_data\\[:([a-zA-Z_][a-zA-Z0-9_]*[?!]?)\\]',
        '@\\1', 'g'
      )
      WHERE #{column} LIKE '%@beacon_live_data[%'
      """

      # @beacon_live_data.key → @key
      execute """
      UPDATE #{table}
      SET #{column} = regexp_replace(
        #{column},
        '@beacon_live_data\\.([a-zA-Z_][a-zA-Z0-9_]*[?!]?)',
        '@\\1', 'g'
      )
      WHERE #{column} LIKE '%@beacon_live_data.%'
      """

      # @beacon_live_data["key"] → @key
      execute """
      UPDATE #{table}
      SET #{column} = regexp_replace(
        #{column},
        '@beacon_live_data\\["([a-zA-Z_][a-zA-Z0-9_]*[?!]?)"\\]',
        '@\\1', 'g'
      )
      WHERE #{column} LIKE '%@beacon_live_data[%'
      """

      # @beacon_path_params → @beacon.path_params
      execute """
      UPDATE #{table}
      SET #{column} = replace(#{column}, '@beacon_path_params', '@beacon.path_params')
      WHERE #{column} LIKE '%@beacon_path_params%'
      """

      # @beacon_query_params → @beacon.query_params
      execute """
      UPDATE #{table}
      SET #{column} = replace(#{column}, '@beacon_query_params', '@beacon.query_params')
      WHERE #{column} LIKE '%@beacon_query_params%'
      """
    end

    # Phase 2: Fix layouts — convert @key to assigns[:key] for live data keys
    # Layouts wrap all pages but not every page defines every live data key,
    # so nil-safe access is required.
    flush()

    live_data_keys =
      from(a in "beacon_live_data_assigns", select: a.key)
      |> repo().all()
      |> Enum.uniq()

    for key <- live_data_keys do
      escaped = String.replace(key, "'", "''")

      execute """
      UPDATE beacon_layouts
      SET template = regexp_replace(
        template,
        '@#{escaped}(?![a-zA-Z0-9_?!])',
        'assigns[:#{escaped}]', 'g'
      )
      WHERE template LIKE '%@#{escaped}%'
      """
    end

    # Phase 3: Update published snapshots (serialized binaries)
    flush()
    update_page_snapshots(live_data_keys)
    update_layout_snapshots(live_data_keys)
  end

  defp update_page_snapshots(live_data_keys) do
    from(s in "beacon_page_snapshots", select: %{id: s.id, page: s.page})
    |> repo().all()
    |> Enum.each(fn %{id: id, page: page_binary} ->
      page = :erlang.binary_to_term(page_binary)
      updated_page = fix_page(page)

      if updated_page != page do
        new_binary = :erlang.term_to_binary(updated_page)
        repo().update_all(from(s in "beacon_page_snapshots", where: s.id == ^id), set: [page: new_binary])
      end
    end)
  end

  defp update_layout_snapshots(live_data_keys) do
    from(s in "beacon_layout_snapshots", select: %{id: s.id, layout: s.layout})
    |> repo().all()
    |> Enum.each(fn %{id: id, layout: layout_binary} ->
      layout = :erlang.binary_to_term(layout_binary)
      updated_layout = fix_template(layout) |> fix_layout_keys(live_data_keys)

      if updated_layout != layout do
        new_binary = :erlang.term_to_binary(updated_layout)
        repo().update_all(from(s in "beacon_layout_snapshots", where: s.id == ^id), set: [layout: new_binary])
      end
    end)
  end

  defp fix_page(page) do
    page
    |> fix_template()
    |> fix_variants()
  end

  defp fix_template(%{template: template} = record) when is_binary(template) do
    %{record | template: replace_deprecated(template)}
  end

  defp fix_template(%{body: body} = record) when is_binary(body) do
    %{record | body: replace_deprecated(body)}
  end

  defp fix_template(record), do: record

  defp fix_variants(%{variants: variants} = page) when is_list(variants) do
    updated =
      Enum.map(variants, fn
        %{template: t} = variant when is_binary(t) ->
          %{variant | template: replace_deprecated(t)}

        variant ->
          variant
      end)

    %{page | variants: updated}
  end

  defp fix_variants(page), do: page

  defp fix_layout_keys(%{template: template} = layout, keys) when is_binary(template) do
    updated =
      Enum.reduce(keys, template, fn key, acc ->
        String.replace(acc, ~r/@#{Regex.escape(key)}(?![a-zA-Z0-9_?!])/, "assigns[:#{key}]")
      end)

    %{layout | template: updated}
  end

  defp fix_layout_keys(layout, _keys), do: layout

  defp replace_deprecated(text) when is_binary(text) do
    text
    |> String.replace(~r/@beacon_live_data\[:([a-zA-Z_][a-zA-Z0-9_]*[?!]?)\]/, "@\\1")
    |> String.replace(~r/@beacon_live_data\.([a-zA-Z_][a-zA-Z0-9_]*[?!]?)/, "@\\1")
    |> String.replace(~r/@beacon_live_data\["([a-zA-Z_][a-zA-Z0-9_]*[?!]?)"\]/, "@\\1")
    |> String.replace("@beacon_path_params", "@beacon.path_params")
    |> String.replace("@beacon_query_params", "@beacon.query_params")
  end

  defp replace_deprecated(text), do: text

  def down do
    :ok
  end
end
```

**Important:**

- The migration updates source tables (drafts), published snapshots (serialized binaries), and layout templates with nil-safe access.
- Identifiers with `?` or `!` suffixes (e.g., `@beacon_live_data[:visible?]`) are handled.
- Older layout snapshots that use `:body` instead of `:template` are handled.
- Layout templates are converted to `assigns[:key]` for all known live data keys to preserve nil-on-missing safety.

### Tailwind CSS compiler replaced

The `{:tailwind, "~> 0.4"}` hex package (which wraps the Tailwind CLI binary) has been **completely removed**. Beacon now uses `{:tailwind_compiler, ...}`, a Zig NIF that compiles CSS entirely in-memory on a dirty CPU scheduler. There are no external processes, no temp files, and no disk I/O.

#### Host app changes required

1. **Remove the old tailwind dependency** from your `mix.exs`:

    ```diff
    - {:tailwind, "~> 0.4"}
    ```

2. **Remove tailwind configuration** from `config/config.exs` and `config/test.exs`:

    ```diff
    - config :tailwind, version: "4.1.12"
    ```

3. **Remove tailwind.install** from your `assets.setup` Mix alias (if present).

4. **Remove `css_compiler:` option** from your `Beacon.Config.new/1` call if you had one — this config field no longer exists.

5. The `tailwind_compiler` dependency is pulled in transitively by Beacon. No explicit dependency needed in your `mix.exs`.

#### What changed

- CSS compiles in <5ms via Zig NIF instead of 2-8 seconds via the Tailwind CLI
- No `node_modules`, no npm, no external binary
- CSS candidate classes are extracted from templates by `Beacon.CSS.CandidateExtractor` (pure Elixir regex)
- First visitor sees a CSS warming page (animated loading screen) instead of waiting for compilation. The page auto-redirects when CSS is ready.

#### Breaking changes in Tailwind v4

See the [official upgrade guide](https://tailwindcss.com/docs/upgrade-guide) for the full list. Key changes:

- Default border color changed from `gray-200` to `currentColor`
- Some utility names renamed: `shadow-sm` → `shadow-xs`, `rounded-sm` → `rounded-xs`
- `!important` modifier moved from prefix to suffix: `!flex` → `flex!`

### Database migration required

Two new migration versions must be applied:

- **V005**: Creates `beacon_css_manifests` table for CSS three-tier storage (ETS → S3 → recompile)
- **V006**: Adds `template` text column to `beacon_page_snapshots` and backfills it. This denormalized column enables fast CSS candidate extraction without deserializing full page binary blobs.

Create a migration in your host app:

```elixir
defmodule MyApp.Repo.Migrations.BeaconV006 do
  use Ecto.Migration
  def up, do: Beacon.Migration.up()
  def down, do: Beacon.Migration.down()
end
```

Run `mix ecto.migrate` **before** deploying the new code.

### Beacon.Loader removed

The entire `Beacon.Loader` system has been deleted (17 files, ~3,100 lines). Dynamic BEAM module compilation at runtime is gone. All rendering now goes through `Beacon.RuntimeRenderer`, which interprets page IR (intermediate representation) directly.

**If your code references any of these modules, it will break at compile time:**

- `Beacon.Loader` / `Beacon.Loader.Worker`
- `Beacon.Loader.Page` / `Beacon.Loader.Layout` / `Beacon.Loader.Components`
- `Beacon.Loader.LiveData` / `Beacon.Loader.Routes`
- `Beacon.Loader.ErrorPage` / `Beacon.Loader.EventHandlers` / `Beacon.Loader.InfoHandlers`
- `Beacon.Loader.Stylesheet` / `Beacon.Loader.Snippets`
- `Beacon.Compiler` / `Beacon.ErrorHandler`

No direct replacement is needed — Beacon handles everything internally via `RuntimeRenderer`. If you were calling `Beacon.Loader` to force a page reload, use the Content API (`Beacon.Content.publish_page/1`) instead, which triggers PubSub events that the RuntimeRenderer picks up automatically.

### Supervision tree changes

The per-site supervision tree has changed:

| Removed | Replacement |
|---------|-------------|
| `Beacon.Loader` (GenServer) | `Beacon.RuntimeRenderer.PubSubHandler` |
| `Beacon.Loader.Worker` (DynamicSupervisor) | Removed (no dynamic workers needed) |

New processes added:

| Process | Purpose |
|---------|---------|
| `Beacon.DataStore.PubSubHandler` | Translates host-app PubSub events to DataStore source invalidations |
| `Beacon.DataStore.TtlChecker` | Periodic check for expired DataStore cache entries |

### Page loading is now lazy

Pages no longer load eagerly at boot. Only a lightweight route index (path → page_id mapping) is loaded. Individual pages load lazily on first request and are cached in ETS. This dramatically reduces boot memory for sites with many pages.

**Impact:** The first request to each page will be slightly slower (loads from DB + compiles IR). Subsequent requests serve from ETS cache. No action required — this is automatic.

### Circuit breaker

A new circuit breaker prevents cascading 500 errors. When a page raises during mount or render, the circuit trips for that path. Subsequent requests return an immediate 500 without executing any page logic, for a configurable TTL.

- **Default:** Enabled, 60-second TTL
- **Disable:** `circuit_breaker_ttl: 0` in your `Beacon.Config`
- **Behavior:** Only 5xx errors trip the breaker. 4xx errors (like 404) are passed through normally.

No action required unless you want to change the default TTL.

### DataStore (opt-in)

`Beacon.DataStore` is a new structured data fetching layer with ETS caching and automatic LiveView invalidation. It replaces the pattern of fetching external data in `live_data` assigns.

This is fully opt-in — if you don't configure `data_sources:`, nothing changes.

#### Configuring data sources

```elixir
Beacon.Config.new(
  site: :my_site,
  data_sources: [
    [name: :blog_posts, fetch: {MyApp.DataSources, :list_posts, []}, ttl: :timer.minutes(5)],
    [name: :featured, fetch: {MyApp.DataSources, :featured, [:limit]}, ttl: :timer.hours(1), params: [:limit]]
  ]
)
```

Each source defines:
- `:name` — atom identifier
- `:fetch` — `{module, function, arg_keys}` MFA tuple. The function receives a single map argument with the resolved params.
- `:ttl` — cache time-to-live in milliseconds
- `:params` — optional list of param keys the source accepts

#### Wiring pages to data sources

Add `data_sources` to a page's `extra` field (via admin or migration):

```json
[
  {"source": "blog_posts", "params": {}, "spread": true},
  {"source": "featured", "params": {"limit": 3}}
]
```

- **`spread: true`**: merges the result map's keys directly into top-level assigns (e.g., `@posts`, `@pagination`) instead of nesting under `@blog_posts`
- **Param resolvers**: static values, `{"path_param": "slug"}` for URL path segments, `{"query_param": "page"}` for query strings, `{"concat_path_params": ["year", "month", "day", "slug"]}` for multi-segment paths

#### Important: update both pages AND snapshots

When wiring data sources via migration, you must update BOTH `beacon_pages.extra` AND `beacon_page_snapshots.extra`:

```sql
-- Update pages
UPDATE beacon_pages
SET extra = jsonb_set(COALESCE(extra, '{}'::jsonb), '{data_sources}', '[...]'::jsonb)
WHERE site = 'my_site' AND path = '/my-page';

-- Update snapshots (RuntimeRenderer reads from here)
UPDATE beacon_page_snapshots
SET extra = jsonb_set(COALESCE(extra, '{}'::jsonb), '{data_sources}', '[...]'::jsonb)
WHERE site = 'my_site' AND path = '/my-page';
```

If you only update `beacon_pages`, the data sources will be invisible to the renderer until the page is republished.

### Live update modes (opt-in)

When a page's dependencies change (template, layout, component, data source), connected LiveViews can be notified in three modes:

| Mode | Behavior |
|------|----------|
| `:automatic` | Immediate re-render pushed to all connected clients (default) |
| `:notify` | Toast notification with "Refresh" button; user opts in |
| `:manual` | No notification; visitor sees update on next page load |

```elixir
Beacon.Config.new(
  site: :my_site,
  live_update: :automatic,
  live_update_overrides: %{
    "blog_post" => :manual
  },
  update_notification_component: MyApp.CustomToast  # optional
)
```

No action required — defaults to `:automatic`.

### CSS safelist for host app templates (opt-in)

Beacon scans CMS content (pages, layouts, components) for Tailwind classes, but cannot scan your host app's templates. If your host app uses Tailwind classes that also appear in Beacon-rendered pages, generate a safelist:

```bash
mix beacon.gen.safelist --module MyAppWeb.BeaconSafelist --paths "lib/*_web/**/*.ex,lib/*_web/**/*.heex"
```

Then add to your config:

```elixir
Beacon.Config.new(
  site: :my_site,
  css_safelist_module: MyAppWeb.BeaconSafelist
)
```

### New configuration options

#### Cache TTLs

- `:cache_ttl` — Site-wide default TTL in seconds. Default: `60`. Set to `:infinity` to never expire.
- `:cache_ttls` — Per-resource-type TTL overrides. Keys: `:pages`, `:layouts`, `:components`, `:css`, `:js`, `:handlers`.
- `:max_cache_entries` — Maximum entries in content cache. Default: `10_000`.

Per-page TTL via the `extra` field:

```elixir
Beacon.Content.update_page(page, %{
  extra: %{"cache_ttl" => 86_400}     # 24 hours
})
```

#### Full config example

```elixir
Beacon.Config.new(
  site: :my_site,
  cache_ttl: 60,
  cache_ttls: %{
    css: 86_400,
    js: 86_400,
    layouts: :infinity,
    components: :infinity,
    pages: 60
  },
  circuit_breaker_ttl: 60,
  live_update: :automatic,
  data_sources: []
)
```

### Dependencies removed

- **`{:tailwind, "~> 0.4"}`** — replaced by `tailwind_compiler` (Zig NIF). Remove from `mix.exs` and all config.
- **Igniter** — removed entirely. Mix tasks simplified to direct file operations.
- **Credo** — removed from CI checks.
- **Provider.Repo** — media binaries are no longer stored in PostgreSQL. Run `Beacon.Migration.up(version: 4)` to make the `file_body` column nullable.
