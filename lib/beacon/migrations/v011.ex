defmodule Beacon.Migrations.V011 do
  @moduledoc false
  use Ecto.Migration

  def up do
    # P1.1: Content Freshness
    alter table(:beacon_pages) do
      add_if_not_exists :date_modified, :utc_datetime_usec
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :date_modified, :utc_datetime_usec
    end

    # P2.1: FAQ Items
    alter table(:beacon_pages) do
      add_if_not_exists :faq_items, {:array, :map}, default: []
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :faq_items, {:array, :map}, default: []
    end

    # P2.2: Authors
    create_if_not_exists table(:beacon_authors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :name, :text, null: false
      add :slug, :text, null: false
      add :bio, :text
      add :job_title, :text
      add :avatar_url, :text
      add :credentials, :text
      add :same_as, {:array, :text}, default: []

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:beacon_authors, [:site, :slug])

    alter table(:beacon_pages) do
      add_if_not_exists :author_id, references(:beacon_authors, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :author_id, :binary_id
    end

    # P1.2: Redirects
    create_if_not_exists table(:beacon_redirects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :source_path, :text, null: false
      add :destination_path, :text, null: false
      add :status_code, :integer, null: false, default: 301
      add :is_regex, :boolean, null: false, default: false
      add :priority, :integer, null: false, default: 0
      add :hit_count, :integer, null: false, default: 0
      add :last_hit_at, :utc_datetime_usec

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:beacon_redirects, [:site, :source_path])
    create_if_not_exists index(:beacon_redirects, [:site])

    # P2.3: Internal Links
    create_if_not_exists table(:beacon_internal_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :source_page_id, references(:beacon_pages, type: :binary_id, on_delete: :delete_all), null: false
      add :target_page_id, references(:beacon_pages, type: :binary_id, on_delete: :nilify_all)
      add :target_path, :text, null: false
      add :anchor_text, :text

      timestamps updated_at: false, type: :utc_datetime_usec
    end

    create_if_not_exists index(:beacon_internal_links, [:site, :source_page_id])
    create_if_not_exists index(:beacon_internal_links, [:site, :target_page_id])
    create_if_not_exists index(:beacon_internal_links, [:site, :target_path])

    # P2.4: SEO Snapshots
    create_if_not_exists table(:beacon_seo_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :snapshot_date, :date, null: false
      add :metrics, :map, null: false, default: %{}

      timestamps updated_at: false, type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:beacon_seo_snapshots, [:site, :snapshot_date])
  end

  def down do
    drop_if_exists unique_index(:beacon_seo_snapshots, [:site, :snapshot_date])
    drop_if_exists table(:beacon_seo_snapshots)

    drop_if_exists index(:beacon_internal_links, [:site, :target_path])
    drop_if_exists index(:beacon_internal_links, [:site, :target_page_id])
    drop_if_exists index(:beacon_internal_links, [:site, :source_page_id])
    drop_if_exists table(:beacon_internal_links)

    drop_if_exists index(:beacon_redirects, [:site])
    drop_if_exists unique_index(:beacon_redirects, [:site, :source_path])
    drop_if_exists table(:beacon_redirects)

    alter table(:beacon_page_snapshots) do
      remove_if_exists :author_id, :binary_id
    end

    alter table(:beacon_pages) do
      remove_if_exists :author_id, :binary_id
    end

    drop_if_exists unique_index(:beacon_authors, [:site, :slug])
    drop_if_exists table(:beacon_authors)

    alter table(:beacon_page_snapshots) do
      remove_if_exists :faq_items, {:array, :map}
    end

    alter table(:beacon_pages) do
      remove_if_exists :faq_items, {:array, :map}
    end

    alter table(:beacon_page_snapshots) do
      remove_if_exists :date_modified, :utc_datetime_usec
    end

    alter table(:beacon_pages) do
      remove_if_exists :date_modified, :utc_datetime_usec
    end
  end
end
