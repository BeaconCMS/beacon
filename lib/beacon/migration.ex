defmodule Beacon.Migration do
  @moduledoc """
  Functions which can be called in an Ecto migration for Beacon installation and upgrades.
  """

  @latest Beacon.Migrations.V001

  def up do
    @latest.up()
  end

  def down do
    @latest.down()
  end
end
