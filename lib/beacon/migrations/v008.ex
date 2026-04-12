defmodule Beacon.Migrations.V008 do
  @moduledoc false
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_graphql_endpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :name, :string, null: false
      add :url, :text, null: false
      add :auth_type, :string, null: false, default: "bearer"
      add :auth_header, :string, default: "Authorization"
      add :auth_value_encrypted, :binary
      add :introspected_schema, :map
      add :sdl_schema, :text
      add :default_ttl, :integer, default: 60
      add :timeout_ms, :integer, default: 10_000
      add :max_retries, :integer, default: 2

      timestamps(inserted_at: :inserted_at, updated_at: :updated_at, type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:beacon_graphql_endpoints, [:site, :name])

    create_if_not_exists table(:beacon_page_queries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :page_id, references(:beacon_pages, type: :binary_id, on_delete: :delete_all), null: false
      add :endpoint_name, :string, null: false
      add :query_string, :text, null: false
      add :variable_bindings, :map, default: %{}
      add :result_alias, :string, null: false
      add :depends_on, :string
      add :sort_order, :integer, default: 0

      timestamps(inserted_at: :inserted_at, updated_at: :updated_at, type: :utc_datetime_usec)
    end

    create_if_not_exists index(:beacon_page_queries, [:page_id])

    alter table(:beacon_event_handlers) do
      add_if_not_exists :format, :string, default: "elixir"
      add_if_not_exists :actions, :map
    end
  end

  def down do
    alter table(:beacon_event_handlers) do
      remove_if_exists :format, :string
      remove_if_exists :actions, :map
    end

    drop_if_exists index(:beacon_page_queries, [:page_id])
    drop_if_exists table(:beacon_page_queries)

    drop_if_exists index(:beacon_graphql_endpoints, [:site, :name])
    drop_if_exists table(:beacon_graphql_endpoints)
  end
end
