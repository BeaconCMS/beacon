defmodule Beacon.Migrations.V010 do
  @moduledoc false
  use Ecto.Migration

  def up do
    alter table(:beacon_pages) do
      add_if_not_exists :meta_description, :text
      add_if_not_exists :canonical_url, :text
      add_if_not_exists :robots, :string
      add_if_not_exists :og_title, :text
      add_if_not_exists :og_description, :text
      add_if_not_exists :og_image, :text
      add_if_not_exists :twitter_card, :string
      add_if_not_exists :page_type, :string, default: "website"
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :meta_description, :text
      add_if_not_exists :canonical_url, :text
      add_if_not_exists :robots, :string
      add_if_not_exists :og_title, :text
      add_if_not_exists :og_description, :text
      add_if_not_exists :og_image, :text
      add_if_not_exists :twitter_card, :string
      add_if_not_exists :page_type, :string, default: "website"
    end

    alter table(:beacon_layouts) do
      add_if_not_exists :default_og_image, :text
      add_if_not_exists :default_twitter_card, :string
    end

    alter table(:beacon_layout_snapshots) do
      add_if_not_exists :default_og_image, :text
      add_if_not_exists :default_twitter_card, :string
    end
  end

  def down do
    alter table(:beacon_layout_snapshots) do
      remove_if_exists :default_twitter_card, :string
      remove_if_exists :default_og_image, :text
    end

    alter table(:beacon_layouts) do
      remove_if_exists :default_twitter_card, :string
      remove_if_exists :default_og_image, :text
    end

    alter table(:beacon_page_snapshots) do
      remove_if_exists :page_type, :string
      remove_if_exists :twitter_card, :string
      remove_if_exists :og_image, :text
      remove_if_exists :og_description, :text
      remove_if_exists :og_title, :text
      remove_if_exists :robots, :string
      remove_if_exists :canonical_url, :text
      remove_if_exists :meta_description, :text
    end

    alter table(:beacon_pages) do
      remove_if_exists :page_type, :string
      remove_if_exists :twitter_card, :string
      remove_if_exists :og_image, :text
      remove_if_exists :og_description, :text
      remove_if_exists :og_title, :text
      remove_if_exists :robots, :string
      remove_if_exists :canonical_url, :text
      remove_if_exists :meta_description, :text
    end
  end
end
