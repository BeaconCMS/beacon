defmodule Beacon.Repo.Migrations.RenameComponentsBodyToTemplate do
  use Ecto.Migration

  def change do
    rename table(:beacon_components), :body, to: :template
  end
end
