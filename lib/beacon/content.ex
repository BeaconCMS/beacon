defmodule Beacon.Content do
  @moduledoc """
  Content Management for sites.
  """

  import Ecto.Query
  alias Beacon.Content.Component
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.Page
  alias Beacon.Content.PageEvent
  alias Beacon.Content.PageField
  alias Beacon.Content.PageSnapshot
  alias Beacon.Content.PageVariant
  alias Beacon.Content.Snippets
  alias Beacon.Content.Stylesheet
  alias Beacon.Lifecycle
  alias Beacon.PubSub
  alias Beacon.Repo
  alias Beacon.Types.Site
  alias Ecto.Changeset

  defp validate_page_template(changeset) do
    format = Changeset.get_field(changeset, :format)
    template = Changeset.get_field(changeset, :template)
    do_validate_page_template(changeset, format, template)
  end

  defp do_validate_page_template(changeset, :heex = _format, template) when is_binary(template) do
    site = Changeset.get_field(changeset, :site)
    path = Changeset.get_field(changeset, :path)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: path}

    case Beacon.Template.HEEx.compile(template, metadata) do
      {:cont, _ast} ->
        {:ok, changeset}

      {:halt, %{description: description}} ->
        {:error, Changeset.add_error(changeset, :template, description)}

      {:halt, _} ->
        {:error, Changeset.add_error(changeset, :template, "invalid template")}
    end
  end

  defp do_validate_page_template(changeset, :markdown = _format, template) when is_binary(template) do
    site = Changeset.get_field(changeset, :site)
    path = Changeset.get_field(changeset, :path)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: path}

    case Beacon.Template.Markdown.convert_to_html(template, metadata) do
      {:cont, _template} ->
        {:ok, changeset}

      {:halt, %{message: message}} ->
        {:error, Changeset.add_error(changeset, :template, message)}
    end
  end

  defp do_validate_page_template(changeset, _format, _template), do: {:ok, changeset}

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking layout changes.

  ## Example

      iex> change_layout(layout, %{title: "New Home"})
      %Ecto.Changeset{data: %Layout{}}

  """
  @doc type: :layouts
  @spec change_layout(Layout.t(), map()) :: Ecto.Changeset.t()
  def change_layout(%Layout{} = layout, attrs \\ %{}) do
    Layout.changeset(layout, attrs)
  end

  @doc """
  Creates a layout.

  ## Example

      iex> create_layout(%{title: "Home"})
      {:ok, %Layout{}}

  """
  @doc type: :layouts
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
  @doc type: :layouts
  @spec create_layout!(map()) :: Layout.t()
  def create_layout!(attrs) do
    case create_layout(attrs) do
      {:ok, layout} -> layout
      {:error, changeset} -> raise "failed to create layout, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a layout.

  ## Example

      iex> update_layout(layout, %{title: "New Home"})
      {:ok, %Layout{}}

  """
  @doc type: :layouts
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
  @doc type: :layouts
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

  @doc type: :layouts
  @spec publish_layout(Ecto.UUID.t()) :: {:ok, Layout.t()} | any()
  def publish_layout(id) when is_binary(id) do
    id
    |> get_layout()
    |> publish_layout()
  end

  @doc false
  def create_layout_event(layout, event) do
    attrs = %{"site" => layout.site, "layout_id" => layout.id, "event" => event}

    %LayoutEvent{}
    |> Changeset.cast(attrs, [:site, :layout_id, :event])
    |> Changeset.validate_required([:site, :layout_id, :event])
    |> Repo.insert()
  end

  @doc false
  def create_layout_snapshot(layout, event) do
    attrs = %{"site" => layout.site, "schema_version" => Layout.version(), "layout_id" => layout.id, "layout" => layout, "event_id" => event.id}

    %LayoutSnapshot{}
    |> Changeset.cast(attrs, [:site, :schema_version, :layout_id, :layout, :event_id])
    |> Changeset.validate_required([:site, :schema_version, :layout_id, :layout, :event_id])
    |> Repo.insert()
  end

  @doc """
  Gets a single layout.

  ## Example

      iex> get_layout("fd70e5fe-9bd8-41ed-94eb-5459c9bb05fc")
      %Layout{}

  """
  @doc type: :layouts
  @spec get_layout(Ecto.UUID.t()) :: Layout.t() | nil
  def get_layout(id) do
    Repo.get(Layout, id)
  end

  @doc type: :layouts
  def get_layout!(id) when is_binary(id) do
    Repo.get!(Layout, id)
  end

  @doc """
  Gets a single layout by `clauses`.

  ## Example

      iex> get_layout_by(site, title: "blog")
      %Layout{}

  """
  @doc type: :layouts
  @spec get_layout_by(Site.t(), keyword(), keyword()) :: Layout.t() | nil
  def get_layout_by(site, clauses, opts \\ []) when is_atom(site) and is_list(clauses) do
    clauses = Keyword.put(clauses, :site, site)
    Repo.get_by(Layout, clauses, opts)
  end

  @doc """
  Returns all layout events with associated snapshot if available.

  ## Example

      iex> list_layout_events(:my_site, layout_id)
      [
        %LayoutEvent{event: :created, snapshot: nil},
        %LayoutEvent{event: :published, snapshot: %LayoutSnapshot{}}
      ]

  """
  @doc type: :layouts
  @spec list_layout_events(Site.t(), Ecto.UUID.t()) :: [LayoutEvent.t()]
  def list_layout_events(site, layout_id) when is_atom(site) and is_binary(layout_id) do
    Repo.all(
      from event in LayoutEvent,
        left_join: snapshot in LayoutSnapshot,
        on: snapshot.event_id == event.id,
        where: event.site == ^site and event.layout_id == ^layout_id,
        preload: [snapshot: snapshot],
        order_by: [desc: event.inserted_at]
    )
  end

  @doc """
  Returns the latest layout event.

  Useful to find the status of a layout.

  ## Example

      iex> get_latest_layout_event(:my_site, layout_id)
      %LayoutEvent{event: :published}

  """
  @doc type: :layouts
  @spec get_latest_layout_event(Site.t(), Ecto.UUID.t()) :: LayoutEvent.t() | nil
  def get_latest_layout_event(site, layout_id) when is_atom(site) and is_binary(layout_id) do
    Repo.one(
      from event in LayoutEvent,
        where: event.site == ^site and event.layout_id == ^layout_id,
        limit: 1,
        order_by: [desc: event.inserted_at]
    )
  end

  @doc """
  List layouts.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records.
    * `:query` - search layouts by title.

  """
  @doc type: :layouts
  @spec list_layouts(Site.t(), keyword()) :: [Layout.t()]
  def list_layouts(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    search = Keyword.get(opts, :query)

    site
    |> query_list_layouts_base()
    |> query_list_layouts_limit(per_page)
    |> query_list_layouts_search(search)
    |> Repo.all()
  end

  defp query_list_layouts_base(site) do
    from l in Layout,
      where: l.site == ^site,
      order_by: [asc: l.title]
  end

  defp query_list_layouts_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_layouts_limit(query, :infinity = _limit), do: query
  defp query_list_layouts_limit(query, _per_page), do: from(q in query, limit: 20)
  defp query_list_layouts_search(query, search) when is_binary(search), do: from(q in query, where: ilike(q.title, ^"%#{search}%"))
  defp query_list_layouts_search(query, _search), do: query

  @doc """
  Returns all published layouts for `site`.

  Layouts are extracted from the latest published `Beacon.Content.LayoutSnapshot`.
  """
  @doc type: :layouts
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
  @doc type: :layouts
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

  # deprecated: to be removed
  @doc false
  def list_distinct_sites_from_layouts do
    Repo.all(from l in Layout, distinct: true, select: l.site, order_by: l.site)
  end

  ## PAGES

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking page changes.

  ## Example

      iex> change_page(page, %{title: "My Campaign"})
      %Ecto.Changeset{data: %Page{}}

  """
  @doc type: :pages
  @spec change_page(Page.t(), map()) :: Ecto.Changeset.t()
  def change_page(%Page{} = page, attrs \\ %{}) do
    Page.create_changeset(page, attrs)
  end

  @doc """
  Validate `page` with the given `params`.

  All `Beacon.Content.PageField` are validated

  """
  @doc type: :pages
  @spec validate_page(Site.t(), Page.t(), map()) :: Ecto.Changeset.t()
  def validate_page(site, %Page{} = page, attrs) when is_map(attrs) do
    {extra_attrs, page_attrs} = Map.pop(attrs, "extra")

    changeset =
      page
      |> change_page(page_attrs)
      |> Map.put(:action, :validate)

    case validate_page_template(changeset) do
      {:ok, changeset} -> PageField.apply_changesets(changeset, site, extra_attrs)
      {:error, changeset} -> changeset
    end
  end

  @doc """
  Creates a new page that's not published.

  ## Example

      iex> create_page(%{"title" => "My New Page"})
      {:ok, %Page{}}

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
  @doc type: :pages
  @spec create_page(map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def create_page(attrs) when is_map(attrs) do
    Repo.transact(fn ->
      changeset = Page.create_changeset(%Page{}, attrs)

      with {:ok, _} <- validate_page_template(changeset),
           {:ok, page} <- Repo.insert(changeset),
           {:ok, _event} <- create_page_event(page, "created"),
           %Page{} = page <- Lifecycle.Page.after_create_page(page) do
        {:ok, page}
      end
    end)
  end

  @doc """
  Creates a page.
  """
  @doc type: :pages
  @spec create_page!(map()) :: Page.t()
  def create_page!(attrs) do
    case create_page(attrs) do
      {:ok, page} -> page
      {:error, changeset} -> raise "failed to create page, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a page.

  ## Example

      iex> update_page(page, %{title: "New Home"})
      {:ok, %Page{}}

  """
  @doc type: :pages
  @spec update_page(Page.t(), map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def update_page(%Page{} = page, attrs) do
    Repo.transact(fn ->
      changeset = Page.update_changeset(page, attrs)

      with {:ok, _} <- validate_page_template(changeset),
           {:ok, page} <- Repo.update(changeset),
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
  @doc type: :pages
  @spec publish_page(Page.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def publish_page(%Page{} = page) do
    Repo.transact(fn ->
      changeset = change_page(page, %{"site" => page.site, "path" => page.path, "format" => page.format, "template" => page.template})

      with {:ok, _} <- validate_page_template(changeset),
           {:ok, event} <- create_page_event(page, "published"),
           {:ok, _snapshot} <- create_page_snapshot(page, event),
           %Page{} = page <- Lifecycle.Page.after_publish_page(page) do
        :ok = PubSub.page_published(page)
        {:ok, page}
      end
    end)
  end

  @doc type: :pages
  @spec publish_page(Ecto.UUID.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def publish_page(id) when is_binary(id) do
    id
    |> get_page()
    |> publish_page()
  end

  @doc """
  Publish multiple `pages`.

  Similar to `publish_page/1` but defers loading dependent resources
  as late as possible making the process faster.

  """
  @doc type: :pages
  @spec publish_pages([Page.t()]) :: {:ok, [Page.t()]}
  def publish_pages(pages) when is_list(pages) do
    publish = fn page ->
      Repo.transact(fn ->
        with {:ok, event} <- create_page_event(page, "published"),
             {:ok, _snapshot} <- create_page_snapshot(page, event) do
          {:ok, page}
        end
      end)
    end

    pages =
      pages
      |> Enum.map(&publish.(&1))
      |> Enum.map(fn
        {:ok, %Page{} = page} -> Lifecycle.Page.after_publish_page(page)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    :ok = PubSub.pages_published(pages)
    {:ok, pages}
  end

  @doc """
  Unpublish `page`.

  Note that page will be removed from your site
  and it will return error 404 for new requests.
  """
  @doc type: :pages
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

  @doc false
  def create_page_event(page, event) do
    attrs = %{"site" => page.site, "page_id" => page.id, "event" => event}

    %PageEvent{}
    |> Changeset.cast(attrs, [:site, :page_id, :event])
    |> Changeset.validate_required([:site, :page_id, :event])
    |> Repo.insert()
  end

  @doc false
  def create_page_snapshot(page, event) do
    attrs = %{"site" => page.site, "schema_version" => Page.version(), "page_id" => page.id, "page" => page, "event_id" => event.id}

    %PageSnapshot{}
    |> Changeset.cast(attrs, [:site, :schema_version, :page_id, :page, :event_id])
    |> Changeset.validate_required([:site, :schema_version, :page_id, :page, :event_id])
    |> Repo.insert()
  end

  @doc """
  Gets a single page.

  A list of preloads may be passed as a second argument.

  ## Examples

      iex> get_page("dba8a99e-311a-4806-af04-dd968c7e5dae")
      %Page{}

      iex> get_page("dba8a99e-311a-4806-af04-dd968c7e5dae", [:layout])
      %Page{layout: %Layout{}}

  """
  @doc type: :pages
  @spec get_page(Ecto.UUID.t()) :: Page.t() | nil
  def get_page(id, preloads \\ []) when is_binary(id) do
    Page
    |> Repo.get(id)
    |> Repo.preload(preloads)
  end

  @doc type: :pages
  def get_page!(id) when is_binary(id) do
    Repo.get!(Page, id)
  end

  @doc """
  Gets a single page by `clauses`.

  ## Example

      iex> get_page_by(site, path: "contact")
      %Page{}

  """
  @doc type: :pages
  @spec get_page_by(Site.t(), keyword(), keyword()) :: Page.t() | nil
  def get_page_by(site, clauses, opts \\ []) when is_atom(site) and is_list(clauses) do
    clauses = Keyword.put(clauses, :site, site)
    Repo.get_by(Page, clauses, opts)
  end

  @doc """
  Returns all page events with associated snapshot if available.

  ## Example

      iex> list_page_events(:my_site, page_id)
      [
        %PageEvent{event: :created, snapshot: nil},
        %PageEvent{event: :published, snapshot: %PageSnapshot{}}
      ]

  """
  @doc type: :page
  @spec list_page_events(Site.t(), Ecto.UUID.t()) :: [PageEvent.t()]
  def list_page_events(site, page_id) when is_atom(site) and is_binary(page_id) do
    Repo.all(
      from event in PageEvent,
        left_join: snapshot in PageSnapshot,
        on: snapshot.event_id == event.id,
        where: event.site == ^site and event.page_id == ^page_id,
        preload: [snapshot: snapshot],
        order_by: [desc: event.inserted_at]
    )
  end

  @doc """
  Returns the latest page event.

  Useful to find the status of a page.

  ## Example

      iex> get_latest_page_event(:my_site, page_id)
      %PageEvent{event: :published}

  """
  @doc type: :pages
  @spec get_latest_page_event(Site.t(), Ecto.UUID.t()) :: PageEvent.t() | nil
  def get_latest_page_event(site, page_id) when is_atom(site) and is_binary(page_id) do
    Repo.one(
      from event in PageEvent,
        where: event.site == ^site and event.page_id == ^page_id,
        limit: 1,
        order_by: [desc: event.inserted_at]
    )
  end

  @doc """
  List pages.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records.
    * `:query` - search pages by path or title

  """
  @doc type: :pages
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

  defp query_list_pages_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_pages_limit(query, :infinity = _limit), do: query
  defp query_list_pages_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_list_pages_search(query, search) when is_binary(search),
    do: from(q in query, where: ilike(q.path, ^"%#{search}%") or ilike(q.title, ^"%#{search}%"))

  defp query_list_pages_search(query, _search), do: query

  @doc """
  Returns all published pages for `site`.

  Unpublished pages are not returned even if it was once published before,
  only the latest status is valid.

  Pages are extracted from the latest published `Beacon.Content.PageSnapshot`.
  """
  @doc type: :pages
  @spec list_published_pages(Site.t()) :: [Layout.t()]
  def list_published_pages(site) do
    events =
      from event in PageEvent,
        where: event.site == ^site,
        distinct: [asc: event.page_id],
        order_by: fragment("inserted_at desc, case when event = 'published' then 0 else 1 end")

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
  @doc type: :pages
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
    Repo.preload(page, :variants, force: true)
  end

  defp extract_page_snapshot(%{schema_version: 2, page: %Page{} = page}) do
    page
  end

  defp extract_page_snapshot(_snapshot), do: nil

  @doc """

  """
  @doc type: :pages
  @spec put_page_extra(Page.t(), map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def put_page_extra(%Page{} = page, attrs) when is_map(attrs) do
    attrs = %{"extra" => attrs}

    page
    |> Ecto.Changeset.cast(attrs, [:extra])
    |> Repo.update()
  end

  # STYLESHEETS

  @doc """
  Creates a stylesheet.

  ## Example

      iex> create_stylesheet(%{field: value})
      {:ok, %Stylesheet{}}

  """
  @doc type: :stylesheets
  @spec create_stylesheet(map()) :: {:ok, Stylesheet.t()} | {:error, Ecto.Changeset.t()}
  def create_stylesheet(attrs \\ %{}) do
    %Stylesheet{}
    |> Stylesheet.changeset(attrs)
    |> Repo.insert()
  end

  @doc type: :stylesheets
  def create_stylesheet!(attrs \\ %{}) do
    case create_stylesheet(attrs) do
      {:ok, stylesheet} -> stylesheet
      {:error, changeset} -> raise "failed to create stylesheet, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a stylesheet.

  ## Example

      iex> update_stylesheet(stylesheet, %{name: new_value})
      {:ok, %Stylesheet{}}

  """
  @doc type: :stylesheets
  @spec update_stylesheet(Stylesheet.t(), map()) :: {:ok, Stylesheet.t()} | {:error, Ecto.Changeset.t()}
  def update_stylesheet(%Stylesheet{} = stylesheet, attrs) do
    stylesheet
    |> Stylesheet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single stylesheet by `clauses`.

  ## Example

      iex> get_stylesheet_by(site, name: "main")
      %Stylesheet{}

  """
  @doc type: :stylesheets
  @spec get_stylesheet_by(Site.t(), keyword(), keyword()) :: Stylesheet.t() | nil
  def get_stylesheet_by(site, clauses, opts \\ []) when is_atom(site) and is_list(clauses) do
    clauses = Keyword.put(clauses, :site, site)
    Repo.get_by(Stylesheet, clauses, opts)
  end

  @doc """
  Returns the list of stylesheets for `site`.

  ## Example

      iex> list_stylesheets()
      [%Stylesheet{}, ...]

  """
  @doc type: :stylesheets
  @spec list_stylesheets(Site.t()) :: [Stylesheet.t()]
  def list_stylesheets(site) do
    Repo.all(
      from s in Stylesheet,
        where: s.site == ^site
    )
  end

  # COMPONENTS

  @doc """
  Creates a component.

  ## Example

      iex> create_component(attrs)
      {:ok, %Component{}}

  """
  @spec create_component(map()) :: {:ok, Component.t()} | {:error, Ecto.Changeset.t()}
  @doc type: :components
  def create_component(attrs \\ %{}) do
    %Component{}
    |> Component.changeset(attrs)
    |> Repo.insert()
  end

  @doc type: :components
  def create_component!(attrs \\ %{}) do
    case create_component(attrs) do
      {:ok, component} -> component
      {:error, changeset} -> raise "failed to create component: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a component.

      iex> update_component(component, %{name: "new_component"})
      {:ok, %Component{}}

  """
  @doc type: :components
  def update_component(%Component{} = component, attrs) do
    component
    |> Component.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single component by `clauses`.

  ## Example

      iex> get_component_by(site, name: "header")
      %Component{}

  """
  @doc type: :components
  @spec get_component_by(Site.t(), keyword(), keyword()) :: Component.t() | nil
  def get_component_by(site, clauses, opts \\ []) when is_atom(site) and is_list(clauses) do
    clauses = Keyword.put(clauses, :site, site)
    Repo.get_by(Component, clauses, opts)
  end

  @doc """
  Returns the list of components for a `site`.

  ## Example

      iex> list_components()
      [%Component{}, ...]

  """
  @doc type: :components
  @spec list_components(Site.t()) :: [Component.t()]
  def list_components(site) do
    Repo.all(from c in Component, where: c.site == ^site)
  end

  # SNIPPETS

  @doc """
  Creates a snippet helper
  """
  @doc type: :snippets
  @spec create_snippet_helper(map()) :: {:ok, Snippets.Helper.t()} | {:error, Ecto.Changeset.t()}
  def create_snippet_helper(attrs) do
    %Snippets.Helper{}
    |> Ecto.Changeset.cast(attrs, [:site, :name, :body])
    |> Ecto.Changeset.validate_required([:site, :name, :body])
    |> Ecto.Changeset.unique_constraint([:site, :name])
    |> Repo.insert()
  end

  @doc type: :snippets
  def create_snippet_helper!(attrs) do
    case create_snippet_helper(attrs) do
      {:ok, helper} -> helper
      {:error, changeset} -> raise "failed to create snippet helper, got: #{inspect(changeset.errors)} "
    end
  end

  @doc """
  Returns the list of snippet helpers for a `site`.

  ## Example

      iex> list_snippet_helpers()
      [%SnippetHelper{}, ...]

  """
  @doc type: :snippets
  @spec list_snippet_helpers(Site.t()) :: [Snippets.Helper.t()]
  def list_snippet_helpers(site) do
    Repo.all(from h in Snippets.Helper, where: h.site == ^site)
  end

  @doc """
  Renders a snippet `template` with the given `assigns`.

  Snippets are small pieces of string with interpolated assigns.

  Think of it as small templates.

  ## Examples

      iex> Beacon.Content.render_snippet("title is {{ page.title }}", %{page: %Page{title: "home"}})
      {:ok, "title is home"}

  Snippets use the [Liquid](https://shopify.github.io/liquid/) template under the hood,
  which means that all [filters](https://shopify.github.io/liquid/basics/introduction/#filters) are available for use, eg:

      iex> Beacon.Content.render_snippet("{{ 'title' | capitalize }}", assigns)
      {:ok, "Title"}

  In situations where the Liquid filters are not enough, you can create helpers
  to process the template using regular Elixir.

  In the next example a `author_name` is created to simulate a query to fetch the author's name:

      iex> page = Beacon.Content.create_page(%{site: "my_site", extra: %{"author_id": 1}})
      iex> Beacon.Content.create_snippet_helper(%{site: "my_site", name: "author_name", body: ~S\"""
      ...> author_id = get_in(assigns, ["page", "extra", "author_id"])
      ...> MyApp.fetch_author_name(author_id)
      ...> \"""
      iex> Beacon.Snippet.render("Author is {{ helper 'author_name' }}", %{page: page})
      {:ok, "Author is Anon"}

  Note that the `:page` assigns is made available as `assigns["page"]` (String.t) due to how Solid works.

  Snipets can be used in:

    * Meta Tag value
    * Page Schema (structured Schema.org tags)

  Allowed assigns:

    * :page (Beacon.Content.Page.t())

  """
  @doc type: :snippets
  @spec render_snippet(String.t(), %{page: Page.t()}) :: {:ok, String.t()} | :error
  def render_snippet(template, assigns) when is_binary(template) and is_map(assigns) do
    page =
      assigns.page
      |> Map.from_struct()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    assigns = %{"page" => page}

    with {:ok, template} <- Solid.parse(template, parser: Snippets.Parser),
         {:ok, template} <- Solid.render(template, assigns) do
      {:ok, to_string(template)}
    else
      # TODO: wrap error and return a Beacon exception
      _error -> :error
    end
  end

  # PAGE VARIANTS

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking variant changes.

  ## Example

      iex> change_page_variant(page_variant, %{name: "Variant A"})
      %Ecto.Changeset{data: %PageVariant{}}

  """
  @doc type: :page_variants
  @spec change_page_variant(PageVariant.t(), map()) :: Ecto.Changeset.t()
  def change_page_variant(%PageVariant{} = page, attrs \\ %{}) do
    PageVariant.changeset(page, attrs)
  end

  @doc """
  Creates a new page variant and returns the page with updated variants association.
  """
  @doc type: :page_variants
  @spec create_variant_for_page(Page.t(), %{name: binary(), template: binary(), weight: integer()}) ::
          {:ok, Page.t()} | {:error, Changeset.t()}
  def create_variant_for_page(page, attrs) do
    page
    |> Ecto.build_assoc(:variants)
    |> PageVariant.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %PageVariant{}} -> {:ok, Repo.preload(page, :variants, force: true)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates a page variant and returns the page with updated variants association.
  """
  @doc type: :page_variants
  @spec update_variant_for_page(Page.t(), PageVariant.t(), map()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def update_variant_for_page(page, variant, attrs) do
    variant
    |> PageVariant.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, %PageVariant{}} -> {:ok, Repo.preload(page, :variants, force: true)}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
