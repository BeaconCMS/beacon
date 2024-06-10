defmodule Beacon.Repo.Migrations.MigrateComponentCategories do
  use Ecto.Migration

  def up do
    execute """
    UPDATE beacon_components
       SET category = 'html_tag'
     WHERE category = 'basic'
    """

    execute """
    UPDATE beacon_components
       SET category = 'element'
     WHERE category != 'basic'
    """
  end

  def down do
  end
end
