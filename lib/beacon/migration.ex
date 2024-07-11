defmodule Beacon.Migration do
  @moduledoc """
  Functions which can be called in an Ecto migration for Beacon installation and upgrades.
  """

  @migrations [Beacon.Migrations.V001, Beacon.Migrations.V002]

  def up do
    for migration <- @migrations do
      migration.up()
    end
  end

  def down do
    for migration <- Enum.reverse(@migrations) do
      migration.down()
    end
  end
end
