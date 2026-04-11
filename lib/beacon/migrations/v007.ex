defmodule Beacon.Migrations.V007 do
  @moduledoc false
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_site_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :key, :string, null: false
      add :value, :text, null: false
      add :format, :string, default: "heex"
      add :description, :text

      timestamps inserted_at: :inserted_at, updated_at: :updated_at, type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:beacon_site_settings, [:site, :key])
  end

  def down do
    drop_if_exists index(:beacon_site_settings, [:site, :key])
    drop_if_exists table(:beacon_site_settings)
  end
end
