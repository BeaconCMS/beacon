defmodule Beacon.Migrations.V012 do
  @moduledoc false
  use Ecto.Migration

  def up do
    # --- Remove content-type-specific columns ---

    # Drop FK constraint before removing author_id
    # (beacon_authors may not exist if V011 was never run with the author table)
    try do
      execute("ALTER TABLE beacon_pages DROP CONSTRAINT IF EXISTS beacon_pages_author_id_fkey")
    rescue
      _ -> :ok
    end

    alter table(:beacon_pages) do
      remove_if_exists :page_type, :string
      remove_if_exists :faq_items, {:array, :map}
      remove_if_exists :author_id, :binary_id
    end

    alter table(:beacon_page_snapshots) do
      remove_if_exists :page_type, :string
      remove_if_exists :faq_items, {:array, :map}
      remove_if_exists :author_id, :binary_id
    end

    # Drop authors table
    drop_if_exists unique_index(:beacon_authors, [:site, :slug])
    drop_if_exists table(:beacon_authors)

    # --- Add template type infrastructure ---

    create_if_not_exists table(:beacon_template_types, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text
      add :name, :text, null: false
      add :slug, :text, null: false
      add :field_definitions, {:array, :map}, null: false, default: []
      add :json_ld_mapping, :map, default: %{}
      add :meta_tag_mapping, {:array, :map}, default: []

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:beacon_template_types, [:site, :slug])

    alter table(:beacon_pages) do
      add_if_not_exists :template_type_id, references(:beacon_template_types, type: :binary_id, on_delete: :nilify_all)
      add_if_not_exists :fields, :map, default: "{}"
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :template_type_id, :binary_id
      add_if_not_exists :fields, :map, default: "{}"
    end
  end

  def down do
    alter table(:beacon_page_snapshots) do
      remove_if_exists :fields, :map
      remove_if_exists :template_type_id, :binary_id
    end

    alter table(:beacon_pages) do
      remove_if_exists :fields, :map
      remove_if_exists :template_type_id, :binary_id
    end

    drop_if_exists unique_index(:beacon_template_types, [:site, :slug])
    drop_if_exists table(:beacon_template_types)

    # Restore content-type columns (best effort)
    alter table(:beacon_pages) do
      add_if_not_exists :page_type, :string, default: "website"
      add_if_not_exists :faq_items, {:array, :map}, default: []
      add_if_not_exists :author_id, :binary_id
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :page_type, :string, default: "website"
      add_if_not_exists :faq_items, {:array, :map}, default: []
      add_if_not_exists :author_id, :binary_id
    end
  end
end
