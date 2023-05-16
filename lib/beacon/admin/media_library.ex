defmodule Beacon.Admin.MediaLibrary do
  @moduledoc """
  The Admin.MediaLibrary context.
  """

  import Ecto.Query, warn: false
  alias Beacon.Repo

  alias Beacon.Admin.MediaLibrary.Asset

  @doc """
  Returns the list of assets.

  ## Examples

      iex> list_assets()
      [%Asset{}, ...]

  """
  def list_assets do
    Repo.all(
      from asset in Asset,
        where: is_nil(asset.deleted_at)
    )
  end

  def search(term) do
    term = term |> String.split() |> Enum.join("%")
    term = "%#{term}%"

    Repo.all(
      from asset in Asset,
        where: is_nil(asset.deleted_at) and ilike(asset.file_name, ^term)
    )
  end

  @doc """
  Gets a single asset.

  Raises `Ecto.NoResultsError` if the Asset does not exist.

  ## Examples

      iex> get_asset!(123)
      %Asset{}

      iex> get_asset!(456)
      ** (Ecto.NoResultsError)

  """
  def get_asset!(id), do: Repo.get!(Asset, id)

  def get_asset!(site, name) do
    Repo.get_by!(Asset, site: site, name: name)
  end

  def upload(metadata) do
    attrs = %{
      site: metadata.site,
      file_name: metadata.name,
      media_type: metadata.media_type
    }

    %Asset{}
    |> Asset.upload_changeset(attrs, metadata)
    |> Repo.insert()
  end

  @doc """
  Soft deletes a asset.

  ## Examples

      iex> soft_delete_asset(asset)
      {:ok, %Asset{}}

      iex> soft_delete_asset(invalid_asset)
      :error

  """
  def soft_delete_asset(%Asset{} = asset) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    update =
      Repo.update_all(
        from(asset in Asset, where: asset.id == ^asset.id),
        set: [deleted_at: now]
      )

    case update do
      {1, _} -> {:ok, Repo.reload(asset)}
      _ -> :error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking asset changes.

  ## Examples

      iex> change_asset(asset)
      %Ecto.Changeset{data: %Asset{}}

  """
  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    Asset.changeset(asset, attrs)
  end
end
