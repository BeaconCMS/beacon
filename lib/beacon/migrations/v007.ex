defmodule Beacon.Migrations.V007 do
  @moduledoc false
  use Ecto.Migration

  def up do
    create_if_not_exists unique_index(:beacon_components, [:site, :name])
  end

  def down do
    drop_if_exists unique_index(:beacon_components, [:site, :name])
  end
end
