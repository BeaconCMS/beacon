defmodule Beacon.Repo.Migrations.RenameTablePageVariants do
  use Ecto.Migration

  def change do
    rename table("page_variants"), to: table("beacon_page_variants")

    rename(index(:page_variants, [:id], name: "page_variants_pkey"),
      to: "beacon_page_variants_pkey"
    )

    rename(index(:page_variants, [:page_id], name: "page_variants_page_id_index"),
      to: "beacon_page_variants_page_id_index"
    )
  end
end
