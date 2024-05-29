defmodule Beacon.Repo.Migrations.AddBodyToComponents do
  use Ecto.Migration

  def change do
    alter table(:beacon_components) do
      add :body, :text
    end
  end
end
