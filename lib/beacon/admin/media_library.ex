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
    Repo.all(Asset)
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

  def upload(site, file_path, file_name, file_type) do
    file_body = File.read!(file_path)
    file_hash = :crypto.hash(:sha, file_body) |> Base.encode16()

    attrs = %{
      site: site,
      file_body: file_body,
      file_hash: file_hash,
      file_name: file_name,
      file_type: file_type
    }

    %Asset{}
    |> Asset.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a asset.

  ## Examples

      iex> delete_asset(asset)
      {:ok, %Asset{}}

      iex> delete_asset(asset)
      {:error, %Ecto.Changeset{}}

  """
  def delete_asset(%Asset{} = asset) do
    Repo.delete(asset)
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
