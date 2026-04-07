defmodule Beacon.Migrations.V005 do
  @moduledoc false
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_css_manifests, primary_key: false) do
      add :site, :text, primary_key: true
      add :hash, :text, null: false
      add :s3_key, :text, null: false

      timestamps inserted_at: :inserted_at, updated_at: false, type: :utc_datetime
    end
  end

  def down do
    drop_if_exists table(:beacon_css_manifests)
  end
end
