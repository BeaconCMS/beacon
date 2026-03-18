defmodule Beacon.Migrations.V004 do
  @moduledoc false
  use Ecto.Migration

  def up do
    alter table(:beacon_assets) do
      modify :file_body, :binary, null: true, from: {:binary, null: false}
    end
  end

  def down do
    # Cannot safely reverse — rows with NULL file_body would fail
    :ok
  end
end
