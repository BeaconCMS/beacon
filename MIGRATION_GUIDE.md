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

### Tailwind CSS upgraded to v4

Beacon now requires **Tailwind CSS v4** via the `{:tailwind, "~> 0.4"}` hex package. The Tailwind compiler uses v4's CSS-first configuration with `@source` directives instead of generating a JavaScript config with `safelist` or writing template files to disk.

#### Host app changes required

1. **Update the tailwind dependency** in your `mix.exs`:

    ```elixir
    {:tailwind, "~> 0.4"}
    ```

2. **Update the tailwind version** in `config/config.exs`:

    ```elixir
    config :tailwind, version: "4.1.12"
    ```

3. **Install the new binary:**

    ```
    mix tailwind.install
    ```

4. **Update your CSS input file** — replace v3 directives with v4 import:

    ```css
    /* Old (v3) */
    @tailwind base;
    @tailwind components;
    @tailwind utilities;

    /* New (v4) */
    @import "tailwindcss";
    ```

5. **If you have a `tailwind.config.js`** — it still works, but is loaded via `@config` in CSS rather than auto-detected. Beacon handles this automatically. Note that `safelist` is no longer supported in JS config — Beacon uses `@source` directives instead.

#### Breaking changes in Tailwind v4

See the [official upgrade guide](https://tailwindcss.com/docs/upgrade-guide) for the full list. Key changes:

- Default border color changed from `gray-200` to `currentColor`
- Some utility names renamed: `shadow-sm` → `shadow-xs`, `rounded-sm` → `rounded-xs`
- `!important` modifier moved from prefix to suffix: `!flex` → `flex!`

### New configuration options

#### Cache TTLs

Two levels of cache TTL configuration have been added to `Beacon.Config`:

- `:cache_ttl` — Site-wide default TTL in seconds. Default: `60`. Set to `:infinity` to never expire.
- `:cache_ttls` — Per-resource-type TTL overrides. Keys: `:pages`, `:layouts`, `:components`, `:css`, `:js`, `:handlers`. Values: seconds or `:infinity`.

Per-page TTL can be set via the `extra` field:

```elixir
Beacon.Content.create_page(site, %{
  ...,
  extra: %{"cache_ttl" => 86_400}     # 24 hours
})

Beacon.Content.update_page(page, %{
  extra: %{"cache_ttl" => "infinity"}  # never expires
})
```

No migration is required. Example configuration:

```elixir
Beacon.Config.new(
  site: :my_site,
  cache_ttl: 60,
  cache_ttls: %{
    css: 86_400,        # 24 hours
    js: 86_400,
    layouts: :infinity,
    components: :infinity,
    pages: 60
  }
)
```

### Dependencies removed

- **Igniter** — removed entirely. Mix tasks simplified to direct file operations.
- **Credo** — removed from CI checks.
- **Provider.Repo** — media binaries are no longer stored in PostgreSQL. Run `Beacon.Migration.up(version: 4)` to make the `file_body` column nullable.
