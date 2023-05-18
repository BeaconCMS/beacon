defmodule Beacon.Repo.Migrations.RenameFileTypeOnAssets do
  use Ecto.Migration

  def change do
    rename table(:beacon_assets), :file_type, to: :media_type
  end
end
