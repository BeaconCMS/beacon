defmodule Beacon.Repo.Migrations.AddPageMetaTags do
  use Ecto.Migration

  def change do
  	alter table(:beacon_pages) do
  		add :meta_tags, :map
  	end
  end
end
