defmodule Beacon.Content do
  @moduledoc """
  Content Management for sites.
  """

  import Ecto.Query
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.Page
  alias Beacon.Content.PageEvent
  alias Beacon.Content.PageField
  alias Beacon.Content.PageSnapshot
  alias Beacon.Lifecycle
  alias Beacon.PubSub
  alias Beacon.Repo
  alias Beacon.Types.Site
  alias Ecto.Changeset

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking layout changes.

  ## Examples

      iex> change_layout(layout, %{title: "New Home"})
      %Ecto.Changeset{data: %Layout{}}

  """
  @spec change_layout(Layout.t(), map()) :: Ecto.Changeset.t()
  def change_layout(%Layout{} = layout, attrs \\ %{}) do
    Layout.changeset(layout, attrs)
  end

  @doc """
  Creates a layout.

  ## Examples

      iex> create_layout(%{title: "Home"})
      {:ok, %Layout{}}

  """
  @spec create_layout(map()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def create_layout(attrs) do
    create = fn attrs ->
      %Layout{}
      |> Layout.changeset(attrs)
      |> Repo.insert()
    end

    Repo.transact(fn ->
      with {:ok, layout} <- create.(attrs),
           {:ok, _event} <- create_layout_event(layout, "created") do
        {:ok, layout}
      end
    end)
  end

  @doc """
  Creates a layout.
  """
  @spec create_layout!(map()) :: Layout.t()
  def create_layout!(attrs) do
    case create_layout(attrs) do
      {:ok, layout} -> layout
      {:error, changeset} -> raise "failed to create layout, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a layout.

  ## Examples

      iex> update_layout(layout, %{title: "New Home"})
      {:ok, %Layout{}}

  """
  @spec update_layout(Layout.t(), map()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def update_layout(%Layout{} = layout, attrs) do
    layout
    |> Layout.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Publishes `layout` and reload resources to render the updated layout and pages.

  Event + snapshot
  """
  @spec publish_layout(Layout.t()) :: {:ok, Layout.t()} | any()
  def publish_layout(%Layout{} = layout) do
    Repo.transact(fn ->
      with {:ok, event} <- create_layout_event(layout, "published"),
           {:ok, _snapshot} <- create_layout_snapshot(layout, event) do
        :ok = PubSub.layout_published(layout)
        {:ok, layout}
      end
    end)
  end

  defp create_layout_event(layout, event) do
    attrs = %{"site" => layout.site, "layout_id" => layout.id, "event" => event}

    %LayoutEvent{}
    |> Changeset.cast(attrs, [:site, :layout_id, :event])
    |> Changeset.validate_required([:site, :layout_id, :event])
    |> Repo.insert()
  end

  defp create_layout_snapshot(layout, event) do
    attrs = %{"site" => layout.site, "schema_version" => Layout.version(), "layout_id" => layout.id, "layout" => layout, "event_id" => event.id}

    %LayoutSnapshot{}
    |> Changeset.cast(attrs, [:site, :schema_version, :layout_id, :layout, :event_id])
    |> Changeset.validate_required([:site, :schema_version, :layout_id, :layout, :event_id])
    |> Repo.insert()
  end

  @doc """
  Gets a single layout.

  ## Examples

      iex> get_layout("fd70e5fe-9bd8-41ed-94eb-5459c9bb05fc")
      %Layout{}

  """
  @spec get_layout(Ecto.UUID.t()) :: Layout.t() | nil
  def get_layout(id) do
    Repo.get(Layout, id)
  end

  def get_layout!(id) when is_binary(id) do
    Repo.get!(Layout, id)
  end

  @doc """
  Returns the list of layouts for `site`.
  """
  @spec list_layouts(Site.t()) :: [Layout.t()]
  def list_layouts(site) do
    Repo.all(from l in Layout, where: l.site == ^site)
  end

  @doc """
  Returns all published layouts for `site`.

  Layouts are extracted from the latest published `Beacon.Content.LayoutSnapshot`.
  """
  @spec list_published_layouts(Site.t()) :: [Layout.t()]
  def list_published_layouts(site) do
    Repo.all(
      from snapshot in LayoutSnapshot,
        join: event in LayoutEvent,
        on: snapshot.event_id == event.id,
        preload: [event: event],
        where: snapshot.site == ^site,
        where: event.event == :published,
        distinct: [asc: snapshot.layout_id],
        order_by: [desc: snapshot.inserted_at]
    )
    |> Enum.map(&extract_layout_snapshot/1)
  end

  @doc """
  Get latest published layout.
  """
  @spec get_published_layout(Site.t(), Ecto.UUID.t()) :: Layout.t() | nil
  def get_published_layout(site, layout_id) do
    Repo.one(
      from snapshot in LayoutSnapshot,
        join: event in LayoutEvent,
        on: snapshot.event_id == event.id,
        preload: [event: event],
        where: snapshot.site == ^site,
        where: event.event == :published,
        where: event.layout_id == ^layout_id and snapshot.layout_id == ^layout_id,
        distinct: [asc: snapshot.layout_id],
        order_by: [desc: snapshot.inserted_at]
    )
    |> extract_layout_snapshot()
  end

  defp extract_layout_snapshot(%{schema_version: 1, layout: %Layout{} = layout}) do
    layout
  end

  defp extract_layout_snapshot(_snapshot), do: nil

  ## PAGES

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking page changes.

  ## Examples

      iex> change_page(page, %{title: "My Campaign"})
      %Ecto.Changeset{data: %Page{}}

  """
  @spec change_page(Page.t(), map()) :: Ecto.Changeset.t()
  def change_page(%Page{} = page, attrs \\ %{}) do
    Page.create_changeset(page, attrs)
  end

  @doc """
  Validate `page` with the given `params`.

  All `Beacon.Content.PageField` are validated

  """
  @spec validate_page(Site.t(), Page.t(), map()) :: Ecto.Changeset.t()
  def validate_page(site, %Page{} = page, params) when is_atom(site) and is_map(params) do
    {extra_params, page_params} = Map.pop(params, "extra")

    page
    |> change_page(page_params)
    |> Map.put(:action, :validate)
    |> PageField.apply_changesets(site, extra_params)
  end

  @doc """
  Creates a new page that's not published.

  ## Examples

      iex> create_page(%{"title" => "My New Page"})

  `attrs` may contain the following string keys:

    * `path` - String.t()
    * `title` - String.t()
    * `description` - String.t()
    * `template` - String.t()
    * `meta_tags` - list(map()) eg: `[%{"property" => "og:title", "content" => "My New Siste"}]`

  See `Beacon.Content.Page` for more info.

  The created page is not published automatically,
  you can make as much changes you need and when the page
  is ready to be published you can call publish_page/1

  It will insert a `created` event into the page timeline,
  and no snapshot is created.
  """
  @spec create_page(map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def create_page(attrs) when is_map(attrs) do
    create = fn attrs ->
      %Page{}
      |> Page.create_changeset(attrs)
      |> Repo.insert()
    end

    Repo.transact(fn ->
      with {:ok, page} <- create.(attrs),
           {:ok, _event} <- create_page_event(page, "created"),
           %Page{} = page <- Lifecycle.Page.after_create_page(page) do
        {:ok, page}
      end
    end)
  end

  @doc """
  Creates a page.
  """
  @spec create_page!(map()) :: Page.t()
  def create_page!(attrs) do
    case create_page(attrs) do
      {:ok, page} -> page
      {:error, changeset} -> raise "failed to create page, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a page.

  ## Examples

      iex> update_page(page, %{title: "New Home"})
      {:ok, %Page{}}

  """
  @spec update_page(Page.t(), map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def update_page(%Page{} = page, attrs) do
    update = fn page, attrs ->
      page
      |> Page.update_changeset(attrs)
      |> Repo.update()
    end

    Repo.transact(fn ->
      with {:ok, page} <- update.(page, attrs),
           %Page{} = page <- Lifecycle.Page.after_update_page(page) do
        {:ok, page}
      end
    end)
  end

  @doc """
  Publish `page`.

  A new snapshot is automatically created to store the page data,
  which is used whenever the site or the page is reloaded. So you
  can keep editing the page as needed without impacting the published page.
  """
  @spec publish_page(Page.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def publish_page(%Page{} = page) do
    Repo.transact(fn ->
      with {:ok, event} <- create_page_event(page, "published"),
           {:ok, _snapshot} <- create_page_snapshot(page, event),
           %Page{} = page <- Lifecycle.Page.after_publish_page(page) do
        :ok = PubSub.page_published(page)
        {:ok, page}
      end
    end)
  end

  @doc """
  Unpublish `page`.

  Note that page will be removed from your site
  and it will return error 404 for new requests.
  """
  @spec unpublish_page(Page.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def unpublish_page(%Page{} = page) do
    Repo.transact(fn ->
      with {:ok, _event} <- create_page_event(page, "unpublished") do
        # TODO: unload page
        :ok = PubSub.page_unpublished(page)
        {:ok, page}
      end
    end)
  end

  defp create_page_event(page, event) do
    attrs = %{"site" => page.site, "page_id" => page.id, "event" => event}

    %PageEvent{}
    |> Changeset.cast(attrs, [:site, :page_id, :event])
    |> Changeset.validate_required([:site, :page_id, :event])
    |> Repo.insert()
  end

  defp create_page_snapshot(page, event) do
    attrs = %{"site" => page.site, "schema_version" => Page.version(), "page_id" => page.id, "page" => page, "event_id" => event.id}

    %PageSnapshot{}
    |> Changeset.cast(attrs, [:site, :schema_version, :page_id, :page, :event_id])
    |> Changeset.validate_required([:site, :schema_version, :page_id, :page, :event_id])
    |> Repo.insert()
  end

  @doc """
  Gets a single page.

  ## Examples

      iex> get_page("dba8a99e-311a-4806-af04-dd968c7e5dae")
      %Page{}

  """
  @spec get_page(Ecto.UUID.t()) :: Page.t() | nil
  def get_page(id) when is_binary(id) do
    Repo.get(Page, id)
  end

  def get_page!(id) when is_binary(id) do
    Repo.get!(Page, id)
  end

  @doc """
  List pages.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records.
    * `:query` - search pages by path or title

  """
  @spec list_pages(Site.t(), keyword()) :: [Page.t()]
  def list_pages(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    search = Keyword.get(opts, :query)

    site
    |> query_list_pages_base()
    |> query_list_pages_limit(per_page)
    |> query_list_pages_search(search)
    |> Repo.all()
  end

  defp query_list_pages_base(site) do
    from p in Page,
      where: p.site == ^site,
      order_by: [asc: p.order, asc: fragment("length(?)", p.path)]
  end

  defp query_list_pages_limit(query, limit) when is_integer(limit) do
    from q in query, limit: ^limit
  end

  defp query_list_pages_limit(query, :infinity = _limit) do
    query
  end

  defp query_list_pages_limit(query, _per_page) do
    from q in query, limit: 20
  end

  defp query_list_pages_search(query, search) when is_binary(search) do
    from q in query,
      where: ilike(q.path, ^"%#{search}%") or ilike(q.title, ^"%#{search}%")
  end

  defp query_list_pages_search(query, _search), do: query

  @doc """
  Returns all published pages for `site`.

  Unpublished pages are not returned even if it was once published before,
  only the latest status is valid.

  Pages are extracted from the latest published `Beacon.Content.PageSnapshot`.
  """
  @spec list_published_pages(Site.t()) :: [Layout.t()]
  def list_published_pages(site) do
    events =
      from event in PageEvent,
        where: event.site == ^site,
        distinct: [asc: event.page_id],
        order_by: [desc: event.inserted_at]

    Repo.all(
      from snapshot in PageSnapshot,
        join: event in subquery(events),
        on: snapshot.event_id == event.id,
        where: snapshot.site == ^site
    )
    |> Enum.map(&extract_page_snapshot/1)
  end

  @doc """
  Get latest published page.
  """
  @spec get_published_page(Site.t(), Ecto.UUID.t()) :: Page.t() | nil
  def get_published_page(site, page_id) do
    events =
      from event in PageEvent,
        where: event.site == ^site,
        where: event.page_id == ^page_id,
        distinct: [asc: event.page_id],
        order_by: [desc: event.inserted_at]

    Repo.one(
      from snapshot in PageSnapshot,
        join: event in subquery(events),
        on: snapshot.event_id == event.id,
        where: snapshot.site == ^site
    )
    |> extract_page_snapshot()
  end

  defp extract_page_snapshot(%{schema_version: 1, page: %Page{} = page}) do
    page
  end

  defp extract_page_snapshot(_snapshot), do: nil

  @doc """
  Returns the latest status for a page.

  The status is the event fetched from `Beacon.Content.PageEvent`

  ## Examples

      iex> get_page_status(page)
      :published

  """
  @spec get_page_status(Page.t()) :: Beacon.Content.PageEvent.event()
  def get_page_status(page) do
    Repo.one(
      from event in PageEvent,
        select: event.event,
        where: event.site == ^page.site,
        where: event.page_id == ^page.id,
        distinct: [asc: event.page_id],
        order_by: [desc: event.inserted_at]
    )
  end

  @deprecated "to be removed"
  def list_distinct_sites_from_layouts do
    Repo.all(from l in Layout, distinct: true, select: l.site, order_by: l.site)
  end
end
