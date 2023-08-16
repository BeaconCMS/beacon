defmodule Beacon.Repo.Migrations.RemovePagesEvents do
  use Ecto.Migration

  def change do
    alter table("beacon_pages") do
      remove_if_exists :events, {:array, :map}
    end
  end
end
