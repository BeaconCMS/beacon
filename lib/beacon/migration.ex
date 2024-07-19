defmodule Beacon.Migration do
  @moduledoc """
  Functions which can be called in an Ecto migration for Beacon installation and upgrades.
  """

  # TODO: `up/1` should execute all migrations from v001 up to `@latest`
  @latest Beacon.Migrations.V001

  def up do
    @latest.up()
  end

  def down do
    @latest.down()
  end
end
