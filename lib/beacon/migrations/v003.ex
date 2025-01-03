defmodule Beacon.Migrations.V003 do
  @moduledoc false
  use Ecto.Migration

  import Ecto.Query

  def up do
    create_if_not_exists table(:beacon_js_hooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :name, :text, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end

  def down do
    drop_if_exists table(:beacon_js_hooks)
  end
end
