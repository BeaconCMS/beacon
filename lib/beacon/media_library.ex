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

  def srcset_for_image(%Asset{} = asset, sources) do
    asset = Repo.preload(asset, :assets)

    asset.assets
    |> filter_sources(sources)
    |> build_srcset()
  end

  def srcset_for_image(_asset, _sources), do: []

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

  @doc """
  Returns the list of all uploaded assets of `site`.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specfic page. Defaults to 1.
    * `:query` - search assets by file name. Defaults to `nil`, doesn't filter query.
    * `:preloads` - a list of preloads to load. Defaults to `[:thumbnail]`.
    * `:sort` - column in which the result will be ordered by. Defaults to `:file_name`.

  """
  @doc type: :assets
  @spec list_assets(Site.t(), keyword()) :: [Asset.t()]
  def list_assets(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :query)
    preloads = Keyword.get(opts, :preloads, [:thumbnail])
    sort = Keyword.get(opts, :sort, :file_name)

    site
    |> query_list_assets_base()
    |> query_list_assets_limit(per_page)
    |> query_list_assets_offset(per_page, page)
    |> query_list_assets_search(search)
    |> query_list_assets_preloads(preloads)
    |> query_list_assets_sort(sort)
    |> Repo.all()
  end

  defp query_list_assets_base(site) do
    from(asset in Asset, where: asset.site == ^site and is_nil(asset.deleted_at) and is_nil(asset.source_id))
  end

  defp query_list_assets_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_assets_limit(query, :infinity = _limit), do: query
  defp query_list_assets_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_list_assets_offset(query, per_page, page) when is_integer(per_page) and is_integer(page) do
    offset = page * per_page - per_page
    from(q in query, offset: ^offset)
  end

  defp query_list_assets_offset(query, _per_page, _page), do: from(q in query, offset: 0)

  defp query_list_assets_search(query, search) when is_binary(search) do
    from(q in query, where: ilike(q.file_name, ^"%#{search}%"))
  end

  defp query_list_assets_search(query, _search), do: query

  defp query_list_assets_preloads(query, [_preload | _] = preloads), do: from(q in query, preload: ^preloads)
  defp query_list_assets_preloads(query, _preloads), do: query

  defp query_list_assets_sort(query, sort), do: from(q in query, order_by: [asc: ^sort])

  @doc """
  Counts the total number of assets based on the amount of pages.

  ## Options

    * `:query` - filter rows count by query. Defaults to `nil`, doesn't filter query.

  """
  @doc type: :assets
  @spec count_assets(Site.t(), keyword()) :: non_neg_integer()
  def count_assets(site, opts \\ []) do
    search = Keyword.get(opts, :query)

    site
    |> query_list_assets_base()
    |> query_list_assets_search(search)
    |> select([q], count(q.id))
    |> Repo.one()
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
