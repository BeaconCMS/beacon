defmodule Beacon.Repo.Migrations.AddThumbnailAndCategoryToComponents do
  use Ecto.Migration

  def change do
    alter table(:beacon_components) do
      add :thumbnail, :string
      add :category, :string
    end
  end
end
