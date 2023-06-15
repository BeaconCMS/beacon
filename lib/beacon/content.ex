defmodule Beacon.Content do
  @moduledoc """
  Manage content for sites.

  TODO
  """

  import Ecto.Query
  alias Beacon.Repo
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.Page
  alias Beacon.Content.PageField
  alias Beacon.Loader
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
    %Layout{}
    |> Layout.changeset(attrs)
    |> Repo.insert()
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
  def publish_layout(%Layout{} = layout) do
    Repo.transact(fn ->
      with {:ok, event} <- create_layout_event(layout, "published"),
           {:ok, _snapshot} <- create_layout_snapshot(layout, event),
           :ok <- Loader.reload_layout(layout) do
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
    attrs = %{"site" => layout.site, "layout" => layout, "event_id" => event.id}

    %LayoutSnapshot{}
    |> Changeset.cast(attrs, [:site, :layout, :event_id])
    |> Changeset.validate_required([:site, :layout, :event_id])
    |> Repo.insert()
  end

  @doc """
  Gets a single layout.

  ## Examples

      iex> get_layout(site, "9BC60ADB-7ACA-4D97-898E-8EC229A653C2")
      %Layout{}

  """
  @spec get_layout(Site.t(), Ecto.UUID.t()) :: Layout.t() | nil
  def get_layout(site, id) do
    Repo.one(from l in Layout, where: l.site == ^site and l.id == ^id)
  end

  @doc """
  Returns the list of layouts for `site`.
  """
  @spec list_layouts(Site.t()) :: [Layout.t()]
  def list_layouts(site) do
    Repo.all(from l in Layout, where: l.site == ^site)
  end

  ## PAGES

  @doc """
  TODO
  """
  @spec change_page(Page.t(), map()) :: Ecto.Changeset.t()
  def change_page(%Page{} = page, attrs \\ %{}) do
    Page.changeset(page, attrs)
  end

  @doc """
  TODO
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
  TODO
  """
  @spec list_pages(Site.t(), String.t()) :: [Page.t()]
  def list_pages(site, search_query, opts \\ [])

  def list_pages(site, search_query, opts) when is_atom(site) and is_binary(search_query) do
    per_page = Keyword.get(opts, :per_page, 20)

    Repo.all(
      from p in Page,
        where: p.site == ^site,
        where: ilike(p.path, ^"%#{search_query}%") or ilike(p.title, ^"%#{search_query}%"),
        limit: ^per_page,
        order_by: [asc: p.order, asc: p.path]
    )
  end

  def list_pages(site, _search_query, opts) when is_atom(site) do
    per_page = Keyword.get(opts, :per_page, 20)

    Repo.all(
      from p in Page,
        where: p.site == ^site,
        limit: ^per_page,
        order_by: [asc: p.order, asc: p.path]
    )
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
    ch = %Page{} |> Page.changeset(attrs)
    IO.inspect(ch)

    ch |> Repo.insert()
  end

  @doc """
  Publish `page`.

  A new snapshot is automatically created to store the page data,
  which is used whenever the site or the page is reloaded. So you
  can keep editing the page as needed without impacting the published page.
  """
  @spec publish_page(Page.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def publish_page(%Page{} = page) do
    # TODO
    {:ok, page}
  end

  @doc """
  Pack a page and store it in a binary format to preserve its current shape and data.

  """
  def store_snapshot(_page_id) do
    # TODO
    page = %Page{}
    {:ok, page}
  end

  @doc false
  def store_snapshot(page_id, event_id) do
  end

  def fetch_snapshot() do
  end
end
