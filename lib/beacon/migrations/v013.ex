defmodule Beacon.Migrations.V013 do
  @moduledoc false
  use Ecto.Migration

  def up do
    # 1. Create beacon_collections table
    create_if_not_exists table(:beacon_collections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text
      add :name, :text, null: false
      add :slug, :text, null: false
      add :description, :text
      add :mode, :text, null: false, default: "managed"
      add :layout_id, references(:beacon_layouts, type: :binary_id, on_delete: :nilify_all)
      add :fields, :jsonb, default: "[]"
      add :json_ld_mapping, :jsonb, default: "{}"
      add :meta_tag_mapping, :jsonb, default: "[]"
      add :starter_template, :text
      add :path_prefix, :text
      add :path_pattern, :text
      add :icon, :text
      add :sort_order, :integer, default: 0

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:beacon_collections, [:site, :slug])

    # 2. Add collection_id to pages and snapshots
    alter table(:beacon_pages) do
      add_if_not_exists :collection_id, references(:beacon_collections, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :collection_id, :binary_id
    end

    flush()

    # 3. Migrate template_types → collections
    migrate_template_types_to_collections()

    # 4. Migrate page references
    migrate_page_references()

    # 5. Remove template_type_id from pages and snapshots
    alter table(:beacon_pages) do
      remove_if_exists :template_type_id, :binary_id
    end

    alter table(:beacon_page_snapshots) do
      remove_if_exists :template_type_id, :binary_id
    end

    # 6. Drop template_types table
    drop_if_exists unique_index(:beacon_template_types, [:site, :slug])
    drop_if_exists table(:beacon_template_types)
  end

  def down do
    # Recreate template_types table
    create_if_not_exists table(:beacon_template_types, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text
      add :name, :text, null: false
      add :slug, :text, null: false
      add :field_definitions, :jsonb, default: "[]"
      add :json_ld_mapping, :jsonb, default: "{}"
      add :meta_tag_mapping, :jsonb, default: "[]"

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:beacon_template_types, [:site, :slug])

    # Add template_type_id back
    alter table(:beacon_pages) do
      add_if_not_exists :template_type_id, references(:beacon_template_types, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :template_type_id, :binary_id
    end

    flush()

    # Reverse migrate collections → template_types
    migrate_collections_to_template_types()

    # Remove collection_id
    alter table(:beacon_pages) do
      remove_if_exists :collection_id, :binary_id
    end

    alter table(:beacon_page_snapshots) do
      remove_if_exists :collection_id, :binary_id
    end

    # Drop collections
    drop_if_exists unique_index(:beacon_collections, [:site, :slug])
    drop_if_exists table(:beacon_collections)
  end

  # ---------------------------------------------------------------------------
  # Data migration helpers
  # ---------------------------------------------------------------------------

  defp migrate_template_types_to_collections do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    # Check if template_types table exists
    result = repo().query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'beacon_template_types')")

    case result do
      {:ok, %{rows: [[true]]}} ->
        rows = repo().query!("SELECT id, site, name, slug, field_definitions, json_ld_mapping, meta_tag_mapping FROM beacon_template_types").rows

        Enum.each(rows, fn [id, site, name, slug, field_defs, json_ld, meta_tags] ->
          collection_id = Ecto.UUID.dump!(Ecto.UUID.generate())

          # Store the mapping for page reference migration
          repo().query!(
            """
            INSERT INTO beacon_collections (id, site, name, slug, description, mode, fields, json_ld_mapping, meta_tag_mapping, sort_order, inserted_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (site, slug) DO NOTHING
            """,
            [collection_id, site, name, slug, "Migrated from template type", "template",
             encode_jsonb(field_defs), encode_jsonb(json_ld), encode_jsonb(meta_tags),
             0, now, now]
          )

          # Update pages that reference this template type
          repo().query!(
            "UPDATE beacon_pages SET collection_id = (SELECT id FROM beacon_collections WHERE slug = $1 AND (site = $2 OR ($2 IS NULL AND site IS NULL)) LIMIT 1) WHERE template_type_id = $3",
            [slug, site, id]
          )

          # Update snapshots
          repo().query!(
            "UPDATE beacon_page_snapshots SET collection_id = (SELECT id FROM beacon_collections WHERE slug = $1 AND (site = $2 OR ($2 IS NULL AND site IS NULL)) LIMIT 1) WHERE template_type_id = $3",
            [slug, site, id]
          )
        end)

      _ ->
        :ok
    end
  end

  defp migrate_page_references do
    # Already handled in migrate_template_types_to_collections
    :ok
  end

  defp migrate_collections_to_template_types do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    rows = repo().query!("SELECT id, site, name, slug, fields, json_ld_mapping, meta_tag_mapping FROM beacon_collections WHERE mode = 'template'").rows

    Enum.each(rows, fn [id, site, name, slug, field_defs, json_ld, meta_tags] ->
      tt_id = Ecto.UUID.dump!(Ecto.UUID.generate())

      repo().query!(
        """
        INSERT INTO beacon_template_types (id, site, name, slug, field_definitions, json_ld_mapping, meta_tag_mapping, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (site, slug) DO NOTHING
        """,
        [tt_id, site, name, slug, encode_jsonb(field_defs), encode_jsonb(json_ld), encode_jsonb(meta_tags), now, now]
      )

      # Update pages
      repo().query!(
        "UPDATE beacon_pages SET template_type_id = (SELECT id FROM beacon_template_types WHERE slug = $1 AND (site = $2 OR ($2 IS NULL AND site IS NULL)) LIMIT 1) WHERE collection_id = $3",
        [slug, site, id]
      )

      repo().query!(
        "UPDATE beacon_page_snapshots SET template_type_id = (SELECT id FROM beacon_template_types WHERE slug = $1 AND (site = $2 OR ($2 IS NULL AND site IS NULL)) LIMIT 1) WHERE collection_id = $3",
        [slug, site, id]
      )
    end)
  end

  defp encode_jsonb(nil), do: "[]"
  defp encode_jsonb(val) when is_binary(val), do: val
  defp encode_jsonb(val), do: Jason.encode!(val)
end
