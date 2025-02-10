defmodule Beacon.Migrations.V004 do
  @moduledoc false
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :site, :text, null: false
      add :capabilities, {:array, :string}

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists table(:beacon_actors_roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, :binary_id, null: false
      add :role_id, references(:beacon_roles), null: false

      timestamps(type: :utc_datetime_usec)
    end
  end

  def down do
    drop_if_exists table(:beacon_actors_roles)
    drop_if_exists table(:beacon_roles)
  end
end
