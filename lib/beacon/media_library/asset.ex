defmodule Beacon.MediaLibrary.Asset do
  @moduledoc """
  Assets are the images, videos, and any other media type uploaded and served by the Media Library.

  > #### Do not create or edit assets manually {: .warning}
  >
  > Use the public functions in `Beacon.MediaLibrary` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Beacon.Schema
  @derive BeaconWeb.Cache.Stale

  @type t :: %__MODULE__{}

  schema "beacon_assets" do
    field :site, Beacon.Types.Site
    field :file_name, :string
    field :file_body, :binary
    field :media_type, :string
    field :deleted_at, :utc_datetime
    field :keys, :map, default: %{}
    field :usage_tag, :string
    field :extra, :map, default: %{}

    belongs_to :source, Beacon.MediaLibrary.Asset

    has_many :assets, Beacon.MediaLibrary.Asset,
      foreign_key: :source_id,
      on_delete: :delete_all,
      where: [usage_tag: {:not, nil}]

    has_one :thumbnail, Beacon.MediaLibrary.Asset,
      foreign_key: :source_id,
      on_delete: :delete_all,
      where: [usage_tag: "thumbnail"]

    timestamps()
  end

  @doc false
  def bare_changeset do
    change(%__MODULE__{})
  end

  @doc false
  def keys_changeset(asset, key, value) do
    keys =
      asset
      |> get_field(:keys)
      |> Map.put(key, value)

    cast(asset, %{keys: keys}, [:keys])
  end
end
