defmodule Beacon.MediaLibrary do
  @moduledoc """
  Media Library to upload and serve assets.
  """
  import Ecto.Query
  import Ecto.Changeset

  alias Beacon.Lifecycle
  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaLibrary.Backend
  alias Beacon.Repo
  alias Beacon.Types.Site

  # TODO: remove all deprecated functions after releasing beacon live admin

  def upload(metadata) do
    with metadata <- Backend.process!(metadata),
         metadata <- send_to_cdns(metadata),
         {:ok, asset} <- save_asset(metadata) do
      Lifecycle.Asset.upload_asset(metadata, asset)
    end
  end

  def send_to_cdns(metadata) do
    metadata
    |> Backend.validate_for_delivery()
    |> Backend.send_to_cdns()
  end

  def save_asset(metadata) do
    metadata
    |> prep_save_asset()
    |> Repo.insert()
  end

  def save_asset!(metadata) do
    metadata
    |> prep_save_asset()
    |> Repo.insert!()
  end

  defp prep_save_asset(metadata) do
    attrs = %{
      site: metadata.site,
      file_name: metadata.name,
      media_type: metadata.media_type
    }

    metadata.resource
    |> cast(attrs, [:site, :file_name, :media_type, :usage_tag])
    |> validate_required([:site, :file_name, :media_type])
    |> Beacon.MediaLibrary.AssetField.apply_changesets(metadata)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking asset changes.

  ## Examples

      iex> change_asset(asset)
      %Ecto.Changeset{data: %Asset{}}

  """
  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:site, :file_name, :media_type, :file_body])
    |> validate_required([:site, :file_name, :media_type, :file_body])
  end

  def change_derivation(change, attrs \\ %{}) do
    change
    |> cast(attrs, [:usage_tag, :source_id])
    |> validate_required([:usage_tag, :source_id])
  end

  def url_for(nil), do: nil

  def url_for(asset) do
    {_, url} =
      asset
      |> backends_for()
      |> hd()
      |> get_url_for(asset)

    url
  end

  def url_for(nil, _), do: nil

  def url_for(asset, backend_key) do
    {_, url} =
      asset
      |> backends_for()
      |> Enum.find(fn backend ->
        backend.backend_key() == backend_key
      end)
      |> get_url_for(asset)

    url
  end

  def urls_for(asset) do
    asset
    |> backends_for()
    |> Enum.map(&get_url_for(&1, asset))
  end

  def srcset_for_image(asset, sources) do
    asset = Repo.preload(asset, :assets)

    asset.assets
    |> filter_sources(sources)
    |> build_srcset()
  end

  defp filter_sources(assets, sources) do
    Enum.filter(
      assets,
      fn asset ->
        Enum.any?(sources, fn source -> asset.usage_tag == source end)
      end
    )
  end

  defp build_srcset(assets) do
    Enum.map(assets, fn asset -> "#{url_for(asset)} #{asset.usage_tag}" end)
  end

  defp backends_for(asset) do
    asset.site
    |> Beacon.Config.fetch!()
    |> Beacon.Config.config_for_media_type(asset.media_type)
    |> Keyword.fetch!(:backends)
  end

  defp get_url_for({backend, config}, asset),
    do: {backend.backend_key(), backend.url_for(asset, config)}

  defp get_url_for(backend, asset), do: {backend.backend_key(), backend.url_for(asset)}

  def is_image?(%{file_name: file_name}) do
    ext = Path.extname(file_name)
    Enum.any?([".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tif", ".tiff", ".webp"], &(&1 == ext))
  end

  @doc """
  Gets a single asset by `clauses`.

  ## Examples

      iex> get_asset_by(site, file_name: "logo.webp")
      %Asset{}

  """
  @spec get_asset_by(Site.t(), keyword()) :: Asset.t() | nil
  def get_asset_by(site, clauses) when is_atom(site) and is_list(clauses) do
    clauses = Keyword.delete(clauses, :site)

    Asset
    |> where([a], a.site == ^site)
    |> where([a], is_nil(a.deleted_at))
    |> where([_a], ^Enum.to_list(clauses))
    |> Repo.one()
  end

  @deprecated "Use get_asset_by/2 instead."
  def get_asset_by(clauses) when is_list(clauses) do
    Asset
    |> where([a], is_nil(a.deleted_at))
    |> where([_a], ^Enum.to_list(clauses))
    |> Repo.one()
  end

  @doc """
  Returns the list of all uploaded assetf of `site`.

  ## Examples

      iex> list_assets(:my_site)
      [%Asset{}, ...]

  """
  @spec list_assets(Site.t()) :: [Asset.t()]
  def list_assets(site) do
    Repo.all(
      from(asset in Asset,
        where: asset.site == ^site,
        where: is_nil(asset.deleted_at),
        where: is_nil(asset.source_id),
        order_by: [desc: asset.inserted_at],
        preload: [:thumbnail]
      )
    )
  end

  @deprecated "Use list_assets/1 instead."
  def list_assets do
    Repo.all(
      from(asset in Asset,
        where: is_nil(asset.deleted_at),
        where: is_nil(asset.source_id),
        order_by: [desc: asset.inserted_at],
        preload: [:thumbnail]
      )
    )
  end

  @deprecated "Use search/2 instead."
  def search(query) do
    query = query |> String.split() |> Enum.join("%")
    query = "%#{query}%"

    Repo.all(
      from(asset in Asset,
        where: is_nil(asset.deleted_at) and ilike(asset.file_name, ^query),
        where: is_nil(asset.source_id),
        preload: [:thumbnail]
      )
    )
  end

  @doc """
  Search assets by file name.
  """
  @spec search(Site.t(), String.t()) :: [Asset.t()]
  def search(site, query) do
    query = query |> String.split() |> Enum.join("%")
    query = "%#{query}%"

    Repo.all(
      from(asset in Asset,
        where: asset.site == ^site,
        where: is_nil(asset.deleted_at) and ilike(asset.file_name, ^query),
        where: is_nil(asset.source_id),
        preload: [:thumbnail]
      )
    )
  end

  @doc """
  Soft deletes a asset.

  ## Examples

      iex> soft_delete(asset)
      {:ok, %Asset{}}

  """
  @spec soft_delete(Asset.t()) :: {:ok, Asset.t()} | :error
  def soft_delete(%Asset{} = asset) do
    update =
      Repo.update_all(
        from(asset in Asset, where: asset.id == ^asset.id),
        set: [deleted_at: DateTime.utc_now()]
      )

    case update do
      {1, _} -> {:ok, Repo.reload(asset)}
      _ -> :error
    end
  end
end
