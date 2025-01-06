defmodule Beacon.Migrations.V003 do
  @moduledoc false
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_js_hooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :name, :text, null: false

      add :mounted, :text
      add :beforeUpdate, :text
      add :updated, :text
      add :destroyed, :text
      add :disconnected, :text
      add :reconnected, :text

      timestamps(type: :utc_datetime_usec)
    end
  end

  def down do
    drop_if_exists table(:beacon_js_hooks)
  end
end
