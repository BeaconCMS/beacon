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
    field :file_name, :string
    field :file_body, :binary
    field :media_type, :string
    field :site, Beacon.Types.Site
    field :deleted_at, :utc_datetime
    field :keys, :map, default: %{}

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
