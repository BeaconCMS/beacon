defmodule Beacon.MediaLibrary do
  @moduledoc """
  Provides functions to upload and serve assets.
  """

  import Ecto.Query
  import Ecto.Changeset
  import Beacon.Utils, only: [repo: 1]

  alias Beacon.Lifecycle
  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaLibrary.Provider
  alias Beacon.MediaLibrary.UploadMetadata
  alias Beacon.Types.Site

  @doc """
  Uploads a given `UploadMetadata` and runs the `:upload_asset` lifecycle.

  Runs multiple steps:

    * Upload to external service (see: `Beacon.MediaLibrary.Provider`)
    * Persist the metadata to the local database
    * Run the `:upload_asset` lifecycle (see: `t:Beacon.Config.lifecycle_stage/0`)

  """
  @spec upload(UploadMetadata.t()) :: Ecto.Schema.t()
  def upload(metadata) do
    with metadata <- Provider.process!(metadata),
         metadata <- send_to_cdns(metadata),
         {:ok, asset} <- save_asset(metadata) do
      Lifecycle.Asset.upload_asset(metadata, asset)
    end
  end

  @doc """
  This functions runs only the external upload step of `upload/1`.
  """
  @spec send_to_cdns(UploadMetadata.t()) :: UploadMetadata.t()
  def send_to_cdns(metadata) do
    metadata
    |> Provider.validate_for_delivery()
    |> Provider.send_to_cdns()
  end

  @doc """
  This functions runs only the local persistence step of `upload/1`.
  """
  @spec save_asset(UploadMetadata.t()) :: {:ok, UploadMetadata.t()} | {:error, Changeset.t()}
  def save_asset(metadata) do
    metadata
    |> prep_save_asset()
    |> repo(metadata).insert()
  end

  @doc """
  Same as `save_asset/1` but raises an error if unsuccessful.
  """
  @spec save_asset!(UploadMetadata.t()) :: UploadMetadata.t()
  def save_asset!(metadata) do
    metadata
    |> prep_save_asset()
    |> repo(metadata).insert!()
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
  @spec change_asset(Asset.t(), map()) :: Changeset.t()
  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:site, :file_name, :media_type, :file_body])
    |> validate_required([:site, :file_name, :media_type, :file_body])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for updating an Asset's `:usage_tag` and/or `:source_id`.

  ## Examples

      iex> change_asset(asset)
      %Ecto.Changeset{data: %Asset{}}

  """
  @spec change_asset(Asset.t(), map()) :: Changeset.t()
  def change_derivation(asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:usage_tag, :source_id])
    |> validate_required([:usage_tag, :source_id])
  end

  @doc """
  Returns a URL for a given asset.

  If multiple URLs exist due to various providers, only the first will be returned.
  """
  @spec url_for(nil) :: nil
  @spec url_for(Asset.t()) :: String.t()
  def url_for(nil), do: nil

  def url_for(asset) do
    {_, url} =
      asset
      |> providers_for()
      |> hd()
      |> get_url_for(asset)

    url
  end

  @doc """
  Uses the given `provider` to determine the URL for a given asset.
  """
  @spec url_for(nil, atom()) :: nil
  @spec url_for(Asset.t(), atom()) :: String.t()
  def url_for(nil, _), do: nil

  def url_for(asset, provider_key) do
    {_, url} =
      asset
      |> providers_for()
      |> Enum.find(fn provider ->
        provider.provider_key() == provider_key
      end)
      |> get_url_for(asset)

    url
  end

  @doc """
  Returns a list of all URLs to the given Asset.

  The number of URLs depends on how many providers are configured for the media type.
  """
  @spec urls_for(Asset.t()) :: [String.t()]
  def urls_for(asset) do
    asset
    |> providers_for()
    |> Enum.map(&get_url_for(&1, asset))
  end

  @doc """
  For a given asset and list of acceptable usage tags, returns a [srcset](https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/srcset) for use in templates.
  """
  @spec srcset_for_image(Asset.t(), [String.t()]) :: [String.t()]
  def srcset_for_image(%Asset{} = asset, sources) do
    asset = repo(asset).preload(asset, :assets)

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

  defp providers_for(asset) do
    asset.site
    |> Beacon.Config.fetch!()
    |> Beacon.Config.config_for_media_type(asset.media_type)
    |> Keyword.fetch!(:providers)
  end

  defp get_url_for({provider, config}, asset),
    do: {provider.provider_key(), provider.url_for(asset, config)}

  defp get_url_for(provider, asset), do: {provider.provider_key(), provider.url_for(asset)}

  @doc """
  Returns true if the given Asset is an image.

  Accepted filetypes are `.jpg .jpeg .png .gif .bmp .tif .tiff .webp`
  """
  @spec is_image?(Asset.t()) :: boolean()
  # credo:disable-for-next-line
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
    |> repo(site).one()
  end

  @doc """
  Returns the list of all uploaded assets of `site`.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specfic page. Defaults to 1.
    * `:query` - search assets by file name. Defaults to `nil`, doesn't filter query.
    * `:preloads` - a list of preloads to load. Defaults to `[:thumbnail]`.
    * `:sort` - column in which the result will be ordered by. Defaults to `:file_name`.
      Allowed values: `:file_name`, `:media_type`.

  """
  @doc type: :assets
  @spec list_assets(Site.t(), keyword()) :: [Asset.t()]
  def list_assets(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :query)
    preloads = Keyword.get(opts, :preloads, [:thumbnail])
    sort = Keyword.get(opts, :sort)
    sort = if sort in [:file_name, :media_type], do: sort, else: :file_name

    site
    |> query_list_assets_base()
    |> query_list_assets_limit(per_page)
    |> query_list_assets_offset(per_page, page)
    |> query_list_assets_search(search)
    |> query_list_assets_preloads(preloads)
    |> query_list_assets_sort(sort)
    |> repo(site).all()
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
    |> repo(site).one()
  end

  @doc """
  Search assets by file name.
  """
  @spec search(Site.t(), String.t()) :: [Asset.t()]
  def search(site, query) do
    query = query |> String.split() |> Enum.join("%")
    query = "%#{query}%"

    repo(site).all(
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
      repo(asset).update_all(
        from(asset in Asset, where: asset.id == ^asset.id),
        set: [deleted_at: DateTime.utc_now()]
      )

    case update do
      {1, _} -> {:ok, repo(asset).reload(asset)}
      _ -> :error
    end
  end
end
