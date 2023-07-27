defmodule Beacon.Repo.Migrations.EmbedPageVariants do
  use Ecto.Migration

  def change do
    alter table("beacon_pages") do
      add :variants, :map, comment: "alternate templates for A/B testing"
    end
  end
end
