defmodule Beacon.Repo.Migrations.AddExampleToComponents do
  use Ecto.Migration

  def up do
    alter table(:beacon_components) do
      add :example, :text, null: true
    end

    execute ~S|
    UPDATE beacon_components
       SET example = 'example'
     WHERE example is null
    |

    alter table(:beacon_components) do
      modify :example, :text, null: false
    end
  end

  def down do
  end
end
