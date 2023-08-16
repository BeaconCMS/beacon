defmodule Beacon.Repo.Migrations.RenameLayoutBodyToTemplate do
  use Ecto.Migration

  def change do
    rename table(:beacon_layouts), :body, to: :template
  end
end
