defmodule Beacon.Repo.Migrations.AddThumbnailAndCategoryToComponents do
  use Ecto.Migration

  def change do
    alter table(:beacon_components) do
      add :thumbnail, :string
      add :category, :string, null: false, default: "other"
    end
  end
end
