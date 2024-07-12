defmodule Beacon.Migrations.V001 do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_assets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :file_name, :string, null: false
      add :media_type, :string, null: false
      add :file_body, :binary, null: false
      add :keys, :map, default: %{}
      add :usage_tag, :text
      add :extra, :map, default: %{}, null: false

      add :source_id, references(:beacon_assets, type: :binary_id)

      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_assets, [:source_id])
    create_if_not_exists index(:beacon_assets, [:usage_tag])

    create_if_not_exists table(:beacon_stylesheets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :name, :text, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists table(:beacon_live_data, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :path, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_live_data, [:site])

    create_if_not_exists table(:beacon_live_data_assigns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :text, null: false
      add :value, :text, null: false
      add :format, :string, null: false

      add :live_data_id, references(:beacon_live_data, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_live_data_assigns, [:live_data_id])

    create_if_not_exists table(:beacon_snippet_helpers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :name, :text, null: false
      add :body, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:beacon_snippet_helpers, [:site, :name])

    create_if_not_exists table(:beacon_components, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :name, :text, null: false
      add :description, :text
      add :thumbnail, :string
      add :body, :text
      add :template, :text, null: false
      add :example, :text, null: false
      add :category, :string, null: false, default: "element"

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists table(:beacon_component_attrs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :struct_name, :string
      add :opts, :binary

      add :component_id, references(:beacon_components, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_component_attrs, [:component_id])

    create_if_not_exists table(:beacon_component_slots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :opts, :binary

      add :component_id, references(:beacon_components, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_component_slots, [:component_id])

    create_if_not_exists table(:beacon_component_slot_attrs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :struct_name, :string
      add :opts, :binary

      add :slot_id,
          references(:beacon_component_slots, on_delete: :delete_all, type: :binary_id),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_component_slot_attrs, [:slot_id])

    create_if_not_exists table(:beacon_layouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :title, :text
      add :template, :text, null: false
      add :meta_tags, {:array, :map}, default: []
      add :resource_links, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists table(:beacon_layout_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :event, :text, null: false

      add :layout_id, references(:beacon_layouts, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create constraint(:beacon_layout_events, :beacon_layout_events_check_event, check: "event = 'created' or event = 'published'")

    create_if_not_exists table(:beacon_layout_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :schema_version, :integer, null: false, comment: "data structure version"
      add :layout, :binary, null: false

      add :layout_id, references(:beacon_layouts, on_delete: :delete_all, type: :binary_id), null: false
      add :event_id, references(:beacon_layout_events, on_delete: :delete_all, type: :binary_id)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create_if_not_exists table(:beacon_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :path, :text, null: false
      add :template, :text, null: false
      add :order, :integer, default: 1
      add :meta_tags, {:array, :map}, default: []
      add :title, :text
      add :description, :text
      add :format, :text, null: false, default: "heex"
      add :extra, :map, default: %{}
      add :raw_schema, {:array, :map}, default: []
      add :helpers, :map

      add :layout_id, references(:beacon_layouts, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:beacon_pages, [:path, :site])

    create_if_not_exists table(:beacon_page_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :event, :text, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create constraint(:beacon_page_events, :beacon_page_events_check_event,
             check: "event = 'created' or event = 'published' or event = 'unpublished'"
           )

    create_if_not_exists table(:beacon_page_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :schema_version, :integer, null: false, comment: "data structure version"
      add :page, :binary, null: false
      add :path, :text, null: false
      add :title, :text, null: false
      add :format, :text, null: false
      add :extra, :map, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id), null: false
      add :event_id, references(:beacon_page_events, on_delete: :delete_all, type: :binary_id)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create_if_not_exists table(:beacon_page_variants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :template, :text, null: false
      add :weight, :integer, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_page_variants, [:page_id])

    create_if_not_exists table(:beacon_page_event_handlers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_page_event_handlers, [:page_id])

    create_if_not_exists table(:beacon_error_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :status, :integer, null: false
      add :template, :text, null: false

      add :layout_id, references(:beacon_layouts, type: :binary_id)

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:beacon_error_pages, [:status, :site])
  end

  def down do
    drop_if_exists table(:beacon_assets)
    drop_if_exists table(:beacon_stylesheets)
    drop_if_exists table(:beacon_live_data_assigns)
    drop_if_exists table(:beacon_live_data)
    drop_if_exists table(:beacon_snippet_helpers)
    drop_if_exists table(:beacon_component_attrs)
    drop_if_exists table(:beacon_component_slot_attrs)
    drop_if_exists table(:beacon_component_slots)
    drop_if_exists table(:beacon_components)
    drop_if_exists table(:beacon_page_snapshots)
    drop_if_exists table(:beacon_page_events)
    drop_if_exists table(:beacon_page_variants)
    drop_if_exists table(:beacon_page_event_handlers)
    drop_if_exists table(:beacon_pages)
    drop_if_exists table(:beacon_error_pages)
    drop_if_exists table(:beacon_layout_snapshots)
    drop_if_exists table(:beacon_layout_events)
    drop_if_exists table(:beacon_layouts)
  end
end
