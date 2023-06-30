defmodule Beacon.Repo.Migrations.AddTableConstraints do
  use Ecto.Migration

  def up do
    alter table("beacon_pages") do
      modify :site, :text, null: false
      modify :path, :text, null: false
      modify :template, :text, null: false
      modify :layout_id, :binary_id, null: false
      modify :meta_tags, {:array, :map}, default: []
    end

    alter table("beacon_layouts") do
      modify :site, :text, null: false
      modify :body, :text, null: false
      modify :meta_tags, {:array, :map}, default: []
    end

    alter table("beacon_components") do
      modify :site, :text, null: false
      modify :name, :text, null: false
      modify :body, :text, null: false
    end

    alter table("beacon_stylesheets") do
      modify :site, :text, null: false
      modify :name, :text, null: false
      modify :content, :text, null: false
    end

    alter table("beacon_assets") do
      modify :site, :text, null: false
      modify :file_name, :string, null: false
      modify :media_type, :string, null: false
      modify :file_body, :binary, null: false
    end
  end

  def down do
  end
end
