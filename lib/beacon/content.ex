defmodule Beacon.Content do
  @moduledoc """
  The building blocks for composing web pages: Layouts, Pages, Components, Stylesheets, and Snippets.

  ## Templates

  Layout and Pages work together as pages require a layout to display its content,
  the minimal template for a layout that can exist is the following:

  ```heex
  <%= @inner_content %>
  ```

  And pages templates can be written in [HEEx](https://hexdocs.pm/phoenix_live_view/assigns-eex.html)
  or [Markdown](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax) formats.

  ## Meta Tags

  Meta Tags can are defined in 3 levels:

    * Site - fixed meta tags displayed on all pages, see `default_site_meta_tags/0`
    * Layouts - applies to all pages used by the template.
    * Page - only applies to the specific page.

  """
  import Ecto.Query

  use GenServer
  require Logger
  alias Beacon.Content.Component
  alias Beacon.Content.ComponentAttr
  alias Beacon.Content.ErrorPage
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.LiveData
  alias Beacon.Content.LiveDataAssign
  alias Beacon.Content.Page
  alias Beacon.Content.PageEvent
  alias Beacon.Content.PageEventHandler
  alias Beacon.Content.PageField
  alias Beacon.Content.PageSnapshot
  alias Beacon.Content.PageVariant
  alias Beacon.Content.Snippets
  alias Beacon.Content.Stylesheet
  alias Beacon.Lifecycle
  alias Beacon.Repo
  alias Beacon.Template.HEEx.HEExDecoder
  alias Beacon.Types.Site
  alias Ecto.Changeset

  @doc false
  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  @doc false
  def table_name(site) do
    String.to_atom("beacon_content_#{site}")
  end

  @doc false
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  @doc false
  def init(config) do
    :ets.new(table_name(config.site), [:ordered_set, :named_table, :public, read_concurrency: true])
    {:ok, config}
  end

  @doc false
  def terminate(_reason, config) do
    :ets.delete(table_name(config.site))
    :ok
  end

  @doc false
  def dump_cached_content(site) when is_atom(site) do
    GenServer.call(name(site), :dump_cached_content)
  end

  defp maybe_broadcast_updated_content_event({:ok, %{site: site}}, resource_type), do: Beacon.PubSub.content_updated(site, resource_type)
  defp maybe_broadcast_updated_content_event({:error, _}, _resource_type), do: :skip

  @doc """
  Returns the list of meta tags that are applied to all pages by default.

  These meta tags can be overwritten or extended on a Layout or Page level.
  """
  @spec default_site_meta_tags() :: [map()]
  def default_site_meta_tags do
    [
      %{"charset" => "utf-8"},
      %{"http-equiv" => "X-UA-Compatible", "content" => "IE=edge"},
      %{"name" => "viewport", "content" => "width=device-width, initial-scale=1"}
    ]
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking layout changes.

  ## Example

      iex> change_layout(layout, %{title: "New Home"})
      %Ecto.Changeset{data: %Layout{}}

  """
  @doc type: :layouts
  @spec change_layout(Layout.t(), map()) :: Changeset.t()
  def change_layout(%Layout{} = layout, attrs \\ %{}) do
    Layout.changeset(layout, attrs)
  end

  @doc """
  Returns a map of attrs to load the default layout into new sites.
  """
  @spec default_layout() :: map()
  @doc type: :layouts
  def default_layout do
    %{
      title: "Default",
      template: "<%= @inner_content %>"
    }
  end

  @doc """
  Creates a layout.

  ## Example

      iex> create_layout(%{title: "Home"})
      {:ok, %Layout{}}

  """
  @doc type: :layouts
  @spec create_layout(map()) :: {:ok, Layout.t()} | {:error, Changeset.t()}
  def create_layout(attrs) do
    changeset = Layout.changeset(%Layout{}, attrs)

    Repo.transact(fn ->
      with {:ok, changeset} <- validate_layout_template(changeset),
           {:ok, layout} <- Repo.insert(changeset),
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
  @spec update_layout(Layout.t(), map()) :: {:ok, Layout.t()} | {:error, Changeset.t()}
  def update_layout(%Layout{} = layout, attrs) do
    changeset = Layout.changeset(layout, attrs)

    with {:ok, changeset} <- validate_layout_template(changeset) do
      Repo.update(changeset)
    end
  end

  @doc """
  Publishes `layout` and reload resources to render the updated layout and pages.

  Event + snapshot

  This operation is serialized.
  """
  @doc type: :layouts
  @spec publish_layout(Layout.t()) :: {:ok, Layout.t()} | {:error, Changeset.t() | term()}
  def publish_layout(%Layout{} = layout) do
    GenServer.call(name(layout.site), {:publish_layout, layout})
  end

  @doc type: :layouts
  @spec publish_layout(Ecto.UUID.t()) :: {:ok, Layout.t()} | any()
  def publish_layout(id) when is_binary(id) do
    id
    |> get_layout()
    |> publish_layout()
  end

  defp validate_layout_template(changeset) do
    site = Changeset.get_field(changeset, :site)
    template = Changeset.get_field(changeset, :template)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: "nopath"}

    case do_validate_template(changeset, :template, :heex, template, metadata) do
      %Changeset{errors: []} = changeset -> {:ok, changeset}
      %Changeset{} = changeset -> {:error, changeset}
    end
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
  Gets a single layout by `id`.

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

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specfic page. Defaults to 1.
    * `:query` - search layouts by title. Defaults to `nil`, doesn't filter query.
    * `:preloads` - a list of preloads to load.
    * `:sort` - column in which the result will be ordered by. Defaults to `:title`.

  """
  @doc type: :layouts
  @spec list_layouts(Site.t(), keyword()) :: [Layout.t()]
  def list_layouts(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :query)
    preloads = Keyword.get(opts, :preloads, [])
    sort = Keyword.get(opts, :sort, :title)

    site
    |> query_list_layouts_base()
    |> query_list_layouts_limit(per_page)
    |> query_list_layouts_offset(per_page, page)
    |> query_list_layouts_search(search)
    |> query_list_layouts_preloads(preloads)
    |> query_list_layouts_sort(sort)
    |> Repo.all()
  end

  defp query_list_layouts_base(site), do: from(l in Layout, where: l.site == ^site)

  defp query_list_layouts_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_layouts_limit(query, :infinity = _limit), do: query
  defp query_list_layouts_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_list_layouts_offset(query, per_page, page) when is_integer(per_page) and is_integer(page) do
    offset = page * per_page - per_page
    from(q in query, offset: ^offset)
  end

  defp query_list_layouts_offset(query, _per_page, _page), do: from(q in query, offset: 0)

  defp query_list_layouts_search(query, search) when is_binary(search), do: from(q in query, where: ilike(q.title, ^"%#{search}%"))
  defp query_list_layouts_search(query, _search), do: query

  defp query_list_layouts_preloads(query, [_preload | _] = preloads), do: from(q in query, preload: ^preloads)
  defp query_list_layouts_preloads(query, _preloads), do: query

  defp query_list_layouts_sort(query, sort), do: from(q in query, order_by: [asc: ^sort])

  @doc """
  Counts the total number of layouts based on the amount of pages.

  ## Options
    * `:query` - filter rows count by query. Defaults to `nil`, doesn't filter query.

  """
  @doc type: :layouts
  @spec count_layouts(Site.t(), keyword()) :: non_neg_integer()
  def count_layouts(site, opts \\ []) do
    search = Keyword.get(opts, :query)

    site
    |> query_list_layouts_base()
    |> query_list_layouts_search(search)
    |> select([q], count(q.id))
    |> Repo.one()
  end

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

  This operation is cached.
  """
  @doc type: :layouts
  @spec get_published_layout(Site.t(), Ecto.UUID.t()) :: Layout.t() | nil
  def get_published_layout(site, layout_id) do
    get_fun = fn ->
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

    GenServer.call(name(site), {:fetch_cached_content, layout_id, get_fun})
  end

  defp extract_layout_snapshot(%{schema_version: 1, layout: %Layout{} = layout}) do
    layout
    |> convert_body_to_template()
    |> convert_stylesheet_urls_to_resource_links()
  end

  defp extract_layout_snapshot(%{schema_version: 2, layout: %Layout{} = layout}) do
    convert_stylesheet_urls_to_resource_links(layout)
  end

  defp extract_layout_snapshot(%{schema_version: 3, layout: %Layout{} = layout}) do
    layout
  end

  defp extract_layout_snapshot(_snapshot), do: nil

  defp convert_body_to_template(layout) do
    {body, layout} = Map.pop(layout, :body)
    Map.put(layout, :template, body)
  end

  defp convert_stylesheet_urls_to_resource_links(layout) do
    {stylesheet_urls, layout} = Map.pop(layout, :stylesheet_urls)

    resource_links =
      Enum.map(stylesheet_urls, fn url ->
        %{
          rel: "stylesheet",
          href: url
        }
      end)

    Map.put(layout, :resource_links, resource_links)
  end

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
  @spec change_page(Page.t(), map()) :: Changeset.t()
  def change_page(%Page{} = page, attrs \\ %{}) do
    Page.create_changeset(page, attrs)
  end

  @doc """
  Validate `page` with the given `params`.

  All `Beacon.Content.PageField` are validated

  """
  @doc type: :pages
  @spec validate_page(Site.t(), Page.t(), map()) :: Changeset.t()
  def validate_page(site, %Page{} = page, attrs) when is_map(attrs) do
    {extra_attrs, page_attrs} = Map.pop(attrs, "extra")

    changeset =
      page
      |> change_page(page_attrs)
      |> Map.put(:action, :validate)

    PageField.apply_changesets(changeset, site, extra_attrs)
  end

  @doc """
  Creates a new page that's not published.

  ## Example

      iex> create_page(%{"title" => "My New Page"})
      {:ok, %Page{}}

  `attrs` may contain the following keys:

    * `path` - String.t()
    * `title` - String.t()
    * `description` - String.t()
    * `template` - String.t()
    * `meta_tags` - list(map()) eg: `[%{"property" => "og:title", "content" => "My New Site"}]`

  See `Beacon.Content.Page` for more info.

  The created page is not published automatically,
  you can make as much changes you need and when the page
  is ready to be published you can call `publish_page/1`

  It will insert a `created` event into the page timeline,
  and no snapshot is created.
  """
  @doc type: :pages
  @spec create_page(map()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def create_page(attrs) when is_map(attrs) do
    attrs =
      Map.new(attrs, fn
        {key, val} when is_binary(key) -> {key, val}
        {key, val} -> {Atom.to_string(key), val}
      end)

    Repo.transact(fn ->
      with {:ok, site} <- Beacon.Types.Site.cast(attrs["site"]),
           attrs = maybe_put_default_meta_tags(site, attrs),
           changeset = Page.create_changeset(%Page{}, attrs),
           {:ok, changeset} <- validate_page_template(changeset),
           {:ok, page} <- Repo.insert(changeset),
           {:ok, _event} <- create_page_event(page, "created"),
           %Page{} = page <- Lifecycle.Page.after_create_page(page) do
        {:ok, page}
      end
    end)
  end

  defp maybe_put_default_meta_tags(site, attrs) do
    default_meta_tags = Beacon.Config.fetch!(site).default_meta_tags
    Map.put_new(attrs, "meta_tags", default_meta_tags)
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
  @spec update_page(Page.t(), map()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def update_page(%Page{} = page, attrs) do
    {ast, attrs} = Map.pop(attrs, "ast")

    attrs =
      if is_nil(ast) do
        attrs
      else
        Map.put(attrs, :template, HEExDecoder.decode(ast))
      end

    changeset = Page.update_changeset(page, attrs)

    Repo.transact(fn ->
      with {:ok, changeset} <- validate_page_template(changeset),
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

  This operation is serialized.
  """
  @doc type: :pages
  @spec publish_page(Page.t()) :: {:ok, Page.t()} | {:error, Changeset.t() | term()}
  def publish_page(%Page{} = page) do
    GenServer.call(name(page.site), {:publish_page, page})
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

    :ok = Beacon.PubSub.pages_published(pages)
    {:ok, pages}
  end

  defp validate_page_template(changeset) do
    site = Changeset.get_field(changeset, :site)
    path = Changeset.get_field(changeset, :path) || "nopath"
    format = Changeset.get_field(changeset, :format)
    template = Changeset.get_field(changeset, :template)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: path}

    case do_validate_template(changeset, :template, format, template, metadata) do
      %Changeset{errors: []} = changeset -> {:ok, changeset}
      %Changeset{} = changeset -> {:error, changeset}
    end
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
        :ok = Beacon.PubSub.page_unpublished(page)
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
    page = Repo.preload(page, [:variants, :event_handlers])

    attrs = %{
      "site" => page.site,
      "schema_version" => Page.version(),
      "event_id" => event.id,
      "page" => page,
      "page_id" => page.id,
      "path" => page.path,
      "title" => page.title,
      "format" => page.format,
      "extra" => page.extra
    }

    fields = [:site, :schema_version, :event_id, :page, :page_id, :path, :title, :format, :extra]

    %PageSnapshot{}
    |> Changeset.cast(attrs, fields)
    |> Changeset.validate_required(fields)
    |> Repo.insert()
  end

  @doc """
  Gets a single page by `id`.

  ## Options

    * `:preloads` - a list of preloads to load.

  ## Examples

      iex> get_page("dba8a99e-311a-4806-af04-dd968c7e5dae")
      %Page{}

      iex> get_page("dba8a99e-311a-4806-af04-dd968c7e5dae", preloads: [:layout])
      %Page{layout: %Layout{}}

  """
  @doc type: :pages
  @spec get_page(Ecto.UUID.t(), keyword()) :: Page.t() | nil
  def get_page(id, opts \\ []) when is_binary(id) and is_list(opts) do
    preloads = Keyword.get(opts, :preloads, [])

    Page
    |> Repo.get(id)
    |> Repo.preload(preloads)
  end

  @doc type: :pages
  def get_page!(id, opts \\ []) when is_binary(id) and is_list(opts) do
    case get_page(id, opts) do
      %Page{} = page -> page
      nil -> raise "page #{id} not found"
    end
  end

  @doc """
  Gets a single page by `clauses`.

  ## Example

      iex> get_page_by(site, path: "/contact")
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
  @doc type: :pages
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

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specfic page. Defaults to 1.
    * `:query` - search pages by path or title.
    * `:preloads` - a list of preloads to load.
    * `:sort` - column in which the result will be ordered by. Defaults to `:title`.

  """
  @doc type: :pages
  @spec list_pages(Site.t(), keyword()) :: [Page.t()]
  def list_pages(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :query)
    preloads = Keyword.get(opts, :preloads, [])
    sort = Keyword.get(opts, :sort, :title)

    site
    |> query_list_pages_base()
    |> query_list_pages_limit(per_page)
    |> query_list_pages_offset(per_page, page)
    |> query_list_pages_search(search)
    |> query_list_pages_preloads(preloads)
    |> query_list_pages_sort(sort)
    |> Repo.all()
  end

  defp query_list_pages_base(site), do: from(p in Page, where: p.site == ^site)

  defp query_list_pages_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_pages_limit(query, :infinity = _limit), do: query
  defp query_list_pages_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_list_pages_offset(query, per_page, page) when is_integer(per_page) and is_integer(page) do
    offset = page * per_page - per_page
    from(q in query, offset: ^offset)
  end

  defp query_list_pages_offset(query, _per_page, _page), do: from(q in query, offset: 0)

  defp query_list_pages_search(query, search) when is_binary(search) do
    from(q in query, where: ilike(q.path, ^"%#{search}%") or ilike(q.title, ^"%#{search}%"))
  end

  defp query_list_pages_search(query, _search), do: query

  defp query_list_pages_preloads(query, [_preload | _] = preloads) do
    from(q in query, preload: ^preloads)
  end

  defp query_list_pages_preloads(query, _preloads), do: query

  defp query_list_pages_sort(query, sort), do: from(q in query, order_by: [asc: ^sort])

  @doc """
  Counts the total number of pages based on the amount of pages.

  ## Options

    * `:query` - filter rows count by query

  """
  @doc type: :pages
  @spec count_pages(Site.t(), keyword()) :: integer()
  def count_pages(site, opts \\ []) do
    search = Keyword.get(opts, :query)

    base = from p in Page, where: p.site == ^site, select: count(p.id)

    base
    |> query_list_pages_search(search)
    |> Repo.one()
  end

  @doc """
  Lists and search all published pages for `site`.

  Note that unpublished pages are not returned even if it was once published before, only the latest snapshot is considered.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specfic page. Defaults to 1.
    * `:search` - search by either one or more fields or dynamic query function.
                  Available fields: `path`, `title`, `format`, `extra`. Defaults to `nil` (do not apply search filter).
    * `:sort` - column in which the result will be ordered by. Defaults to `:title`.

  ## Examples

      iex> list_published_pages(:my_site, search: %{path: "/home", title: "Home Page"})
      [%Page{}]

      iex> list_published_pages(:my_site, search: %{extra: %{"tags" => "press"}})
      [%Page{}]

      iex> list_published_pages(:my_site, search: fn -> dynamic([q], fragment("extra->>'tags' ilike 'year-20%'")) end)
      [%Page{}]

  """
  @doc type: :pages
  @spec list_published_pages(Site.t(), keyword()) :: [Page.t()]
  def list_published_pages(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :search)
    sort = Keyword.get(opts, :sort, :title)

    site
    |> query_list_published_pages_base()
    |> query_list_published_pages_limit(per_page)
    |> query_list_published_pages_offset(per_page, page)
    |> query_list_published_pages_search(search)
    |> query_list_published_pages_sort(sort)
    |> Repo.all()
    |> Enum.map(&extract_page_snapshot/1)
  end

  defp query_list_published_pages_base(site) do
    events =
      from event in PageEvent,
        where: event.site == ^site,
        distinct: [asc: event.page_id],
        order_by: fragment("inserted_at desc, case when event = 'published' then 0 else 1 end")

    from snapshot in PageSnapshot,
      join: event in subquery(events),
      on: snapshot.event_id == event.id,
      where: snapshot.site == ^site
  end

  defp query_list_published_pages_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_published_pages_limit(query, :infinity = _limit), do: query
  defp query_list_published_pages_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_list_published_pages_offset(query, per_page, page) when is_integer(per_page) and is_integer(page) do
    offset = page * per_page - per_page
    from(q in query, offset: ^offset)
  end

  defp query_list_published_pages_offset(query, _per_page, _page), do: from(q in query, offset: 0)

  defp query_list_published_pages_search(query, search) when is_function(search, 0) do
    from(q in query, where: ^search.())
  end

  defp query_list_published_pages_search(query, search) when is_map(search) do
    where =
      Enum.reduce(search, dynamic(true), fn
        {field, value}, dynamic when field in [:path, :title, :format] and is_binary(value) ->
          dynamic([q], ^dynamic and ilike(field(q, ^field), ^value))

        {:extra, {field, value}}, dynamic when is_binary(value) ->
          dynamic([q], ^dynamic and ilike(json_extract_path(q.extra, [^field]), ^value))

        _, dynamic ->
          dynamic
      end)

    from(q in query, where: ^where)
  end

  defp query_list_published_pages_search(query, _search), do: query

  defp query_list_published_pages_sort(query, sort), do: from(q in query, order_by: [asc: ^sort])

  @doc """
  Get latest published page.

  This operation is cached.
  """
  @doc type: :pages
  @spec get_published_page(Site.t(), Ecto.UUID.t()) :: Page.t() | nil
  def get_published_page(site, page_id) do
    get_fun = fn ->
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

    GenServer.call(name(site), {:fetch_cached_content, page_id, get_fun})
  end

  defp extract_page_snapshot(%{schema_version: 1, page: %Page{} = page}) do
    page
    |> Repo.reload()
    |> Repo.preload([:variants, :event_handlers], force: true)
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(%{schema_version: 2, page: %Page{} = page}) do
    page
    |> Repo.reload()
    |> Repo.preload([:variants, :event_handlers], force: true)
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(%{schema_version: 3, page: %Page{} = page}) do
    page
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(_snapshot), do: nil

  defp maybe_add_leading_slash(%{path: <<"/", _rest::binary>>} = page), do: page

  defp maybe_add_leading_slash(page) do
    path = "/" <> page.path
    %{page | path: path}
  end

  @doc """

  """
  @doc type: :pages
  @spec put_page_extra(Page.t(), map()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def put_page_extra(%Page{} = page, attrs) when is_map(attrs) do
    attrs = %{"extra" => attrs}

    page
    |> Changeset.cast(attrs, [:extra])
    |> Repo.update()
  end

  # STYLESHEETS

  @doc """
  Creates a stylesheet.

  ## Example

      iex >create_stylesheet(%{
        site: :my_site,
        name: "override",
        content: ~S|
        @media (min-width: 768px) {
          .md\:text-red-400 {
            color: red;
          }
        }
        |
      })
      {:ok, %Stylesheet{}}

  Note that escape characters must be preserved, so you should use `~S` to avoid issues.

  """
  @doc type: :stylesheets
  @spec create_stylesheet(map()) :: {:ok, Stylesheet.t()} | {:error, Changeset.t()}
  def create_stylesheet(attrs \\ %{}) do
    %Stylesheet{}
    |> Stylesheet.changeset(attrs)
    |> Repo.insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :stylesheet))
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
  @spec update_stylesheet(Stylesheet.t(), map()) :: {:ok, Stylesheet.t()} | {:error, Changeset.t()}
  def update_stylesheet(%Stylesheet{} = stylesheet, attrs) do
    stylesheet
    |> Stylesheet.changeset(attrs)
    |> Repo.update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :stylesheet))
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

  @doc false
  #  Returns the list of components that are loaded by default into new sites.
  @spec blueprint_components() :: [map()]
  def blueprint_components do
    [
      %{
        name: "div",
        description: "div",
        thumbnail: "https://placehold.co/400x75?text=div",
        template: "<div>block</div>",
        example: "<div>block</div>",
        category: :html_tag
      },
      %{
        name: "p",
        description: "p",
        thumbnail: "https://placehold.co/400x75?text=p",
        template: "<p>paragraph</p>",
        example: "<p>paragraph</p>",
        category: :html_tag
      },
      %{
        name: "h1",
        description: "header 1",
        thumbnail: "https://placehold.co/400x75?text=h1",
        template: "<h1>h1</h1>",
        example: "<h1>h1</h1>",
        category: :html_tag
      },
      %{
        name: "h2",
        description: "header 2",
        thumbnail: "https://placehold.co/400x75?text=h2",
        template: "<h2>h2</h2>",
        example: "<h2>h2</h2>",
        category: :html_tag
      },
      %{
        name: "h3",
        description: "header 3",
        thumbnail: "https://placehold.co/400x75?text=h3",
        template: "<h3>h3</h3>",
        example: "<h3>h3</h3>",
        category: :html_tag
      },
      %{
        name: "h4",
        description: "header 4",
        thumbnail: "https://placehold.co/400x75?text=h4",
        template: "<h4>h4</h4>",
        example: "<h4>h4</h4>",
        category: :html_tag
      },
      %{
        name: "h5",
        description: "header 5",
        thumbnail: "https://placehold.co/400x75?text=h5",
        template: "<h5>h5</h5>",
        example: "<h5>h5</h5>",
        category: :html_tag
      },
      %{
        name: "h6",
        description: "header 6",
        thumbnail: "https://placehold.co/400x75?text=h6",
        template: "<h6>h6</h6>",
        example: "<h6>h6</h6>",
        category: :html_tag
      },
      # %{
      #   name: "live_data",
      #   description: "Fetches and render Live Data assign",
      #   thumbnail: "https://placehold.co/400x75?text=live_data",
      #   attrs: [
      #     %{name: "assign", type: "any", opts: [required: true]},
      #     %{name: "default", type: "any", opts: [required: false, default: nil]}
      #   ],
      #   template: "<%= @assign || @default %>",
      #   example: ~S|<.live_data assign={assigns[:username]} default="default" />|,
      #   category: :data
      # },
      %{
        name: "html_tag",
        description: "Renders a HTML tag dynamically",
        thumbnail: "https://placehold.co/400x75?text=dynamic_tag",
        attrs: [
          %{name: "name", type: "string", opts: [required: true]},
          %{name: "class", type: "string", opts: [default: nil]}
        ],
        slots: [
          %{name: "inner_block", opts: [required: true]}
        ],
        template: ~S|<.dynamic_tag name={@name} class={@class}><%= render_slot(@inner_block) %></.dynamic_tag>|,
        example: ~S|<.html_tag name="p" class="text-xl">content</.tag>|,
        category: :element
      },
      %{
        name: "page_link",
        description: "Renders a link to another Beacon page",
        thumbnail: "https://placehold.co/400x75?text=page_link",
        attrs: [
          %{name: "path", type: "string", opts: [required: true]},
          %{name: "rest", type: "global"}
        ],
        slots: [
          %{name: "inner_block", opts: [required: true]}
        ],
        template: ~S|<.link patch={@path} {@rest}><%= render_slot(@inner_block) %></.link>|,
        example: ~S|<.page_link path={~P"/contact"} class="text-xl">Contact Us</.page_link>|,
        category: :element
      },
      %{
        name: "table",
        description: "Renders a table with generic styling",
        thumbnail: "https://placehold.co/400x75?text=table",
        attrs: [
          %{name: "id", type: "string", opts: [required: true]},
          %{name: "rows", type: "list", opts: [required: true]},
          %{name: "row_id", type: "any", opts: [default: nil]},
          %{name: "row_click", type: "any", opts: [default: nil]},
          %{name: "row_item", type: "any", opts: [default: &Function.identity/1]}
        ],
        slots: [
          %{name: "col", opts: [required: true], attrs: [%{name: "label", type: "string"}]},
          %{name: "action"}
        ],
        body: ~S"""
        assigns =
            with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
              assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
            end
        """,
        template: ~S"""
        <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
          <table class="w-[40rem] mt-11 sm:w-full">
            <thead class="text-sm text-left leading-6 text-zinc-500">
              <tr>
                <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal"><%= col[:label] %></th>
                <th :if={@action != []} class="relative p-0 pb-4">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody
              id={@id}
              phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
              class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
            >
              <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
                <td
                  :for={{col, i} <- Enum.with_index(@col)}
                  phx-click={@row_click && @row_click.(row)}
                  class={["relative p-0", @row_click && "hover:cursor-pointer"]}
                >
                  <div class="block py-4 pr-6">
                    <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                    <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                      <%= render_slot(col, @row_item.(row)) %>
                    </span>
                  </div>
                </td>
                <td :if={@action != []} class="relative w-14 p-0">
                  <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                    <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                    <span :for={action <- @action} class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700">
                      <%= render_slot(action, @row_item.(row)) %>
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        """,
        example: ~S|
              <.table id="users" rows={[%{id: 1, username: "admin"}]}>
                <:col :let={user} label="id"><%= user.id %></:col>
                <:col :let={user} label="username"><%= user.username %></:col>
              </.table>
              |,
        category: :element
      },
      %{
        name: "image",
        description: "Renders a image previously uploaded in Admin Media Library",
        thumbnail: "https://placehold.co/400x75?text=image",
        attrs: [
          %{name: "site", type: "atom", opts: [required: true]},
          %{name: "name", type: "string", opts: [required: true]},
          %{name: "class", type: "string", opts: [default: nil]},
          %{name: "rest", type: "global"}
        ],
        template: ~S|<img src={beacon_asset_url(@name)} class={@class} {@rest} />|,
        example: ~S|<.image site={@beacon.site} name="logo.webp" class="w-24 h-24" alt="logo" />|,
        category: :media
      },
      %{
        name: "embedded",
        description: "Renders embedded content like an YouTube video",
        thumbnail: "https://placehold.co/400x75?text=embedded",
        attrs: [%{name: "url", type: "string", opts: [required: true]}],
        body: ~S|
        {:ok, %{html: html}} = OEmbed.for(assigns.url)
        assigns = Map.put(assigns, :html, html)
        |,
        template: ~S|<%= Phoenix.HTML.raw(@html) %>|,
        example: ~S|<.embedded url={"https://www.youtube.com/watch?v=agkXUp0hCW8"} />|,
        category: :media
      },
      %{
        name: "reading_time",
        description: "Renders the estimated time in minutes to read the current page.",
        thumbnail: "https://placehold.co/400x75?text=reading_time",
        attrs: [
          %{name: "site", type: "atom", opts: [required: true]},
          %{name: "path", type: "string", opts: [required: true]},
          %{name: "words_per_minute", type: "integer", opts: [default: 270]}
        ],
        body: ~S"""
        estimated_time_in_minutes =
          case Beacon.Content.get_page_by(assigns.site, path: assigns.path) do
            nil ->
              0

            %{template: template} ->
              template_without_html_tags = String.replace(template, ~r/(<[^>]*>|\n|\s{2,})/, "", global: true)
              words = String.split(template_without_html_tags, " ") |> length()
              Kernel.trunc(words / assigns.words_per_minute)
          end

        assigns = Map.put(assigns, :estimated_time_in_minutes, estimated_time_in_minutes)
        """,
        template: ~S|<%= @estimated_time_in_minutes %>|,
        example: ~S|<.reading_time site={@beacon.site} path={@beacon.page.path} />|,
        category: :element
      },
      %{
        name: "featured_pages",
        description: "Renders a block of featured pages.",
        thumbnail: "https://placehold.co/400x75?text=featured_pages",
        attrs: [
          %{name: "site", type: "atom", opts: [required: true]},
          %{name: "pages", type: "list", opts: [default: []]}
        ],
        slots: [
          %{name: "inner_block", opts: [default: nil]}
        ],
        body: ~S"""
        assigns =
          if Enum.empty?(assigns.pages),
            do: Map.put(assigns, :pages, Beacon.Content.list_published_pages(assigns.site, per_page: 3)),
            else: assigns
        """,
        template: ~S"""
        <div class="max-w-7xl mx-auto">
          <div class="md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-6 lg:gap-11 md:space-y-0 space-y-10">
            <%= if Enum.empty?(@inner_block) do %>
              <div :for={page <- @pages}>
                <article class="hover:ring-2 hover:ring-gray-200 hover:ring-offset-8 flex relative flex-col rounded-lg xl:hover:ring-offset-[12px] 2xl:hover:ring-offset-[16px] active:ring-gray-200 active:ring-offset-8 xl:active:ring-offset-[12px] 2xl:active:ring-offset-[16px] focus-within:ring-2 focus-within:ring-blue-200 focus-within:ring-offset-8 xl:focus-within:ring-offset-[12px] hover:bg-white active:bg-white trasition-all duration-300">
                  <div class="flex flex-col">
                    <div>
                      <p class="font-bold text-gray-700"></p>
                      <p class="text-eyebrow font-medium text-gray-500 text-sm text-left">
                        <%= Calendar.strftime(page.updated_at, "%d %B %Y") %>
                      </p>
                    </div>

                    <div class="-order-1 flex gap-x-2 items-center mb-3">
                      <h3 class="font-heading lg:text-xl lg:leading-8 text-lg font-bold leading-7">
                        <.link
                          patch={page.path}
                          class="after:absolute after:inset-0 after:cursor-pointer focus:outline-none">
                          <%= page.title %>
                        </.link>
                      </h3>
                    </div>
                  </div>
                </article>
              </div>
            <% else %>
              <%= for page <- @pages do %>
                <%= render_slot(@inner_block, page) %>
              <% end %>
            <% end %>
          </div>
        </div>
        """,
        example: ~S"""
        <.featured_pages :let={page} pages={Beacon.Content.list_published_pages(@beacon.site, per_page: 3)}>
          <article >
            <%= page.title %>
          </article>
        </.featured_pages>
        """
      }
    ]
  end

  @doc """
  Returns a list of all existing component categories.
  """
  @doc type: :components
  @spec component_categories() :: [atom()]
  def component_categories, do: Component.categories()

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking component changes.

  ## Example

      iex> change_component(component, %{name: "Header"})
      %Ecto.Changeset{data: %Component{}}

  """
  @doc type: :components
  @spec change_component(Component.t(), map()) :: Changeset.t()
  def change_component(%Component{} = component, attrs \\ %{}) do
    Component.changeset(component, attrs)
  end

  @doc """
  Creates a component.

  ## Example

      iex> create_component(attrs)
      {:ok, %Component{}}

  """
  @spec create_component(map()) :: {:ok, Component.t()} | {:error, Changeset.t()}
  @doc type: :components
  def create_component(attrs \\ %{}) do
    %Component{}
    |> Component.changeset(attrs)
    |> validate_component_template()
    |> Repo.insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :component))
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
  @spec update_component(Component.t(), map()) :: {:ok, Component.t()} | {:error, Changeset.t()}
  def update_component(%Component{} = component, attrs) do
    component
    |> Component.changeset(attrs)
    |> validate_component_template()
    |> Repo.update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :component))
  end

  defp validate_component_template(changeset) do
    site = Changeset.get_field(changeset, :site)
    template = Changeset.get_field(changeset, :template)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: "nopath"}
    do_validate_template(changeset, :template, :heex, template, metadata)
  end

  @doc """
  Gets a single component by `id`.

  ## Example

      iex> get_component("788b2161-b23a-48ed-abcd-8af788004bbb")
      %Component{}

  """
  @doc type: :components
  @spec get_component(Ecto.UUID.t()) :: Component.t() | nil
  def get_component(id) when is_binary(id) do
    Repo.get(Component, id)
  end

  @doc type: :components
  def get_component!(id) when is_binary(id) do
    Repo.get!(Component, id)
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
    Repo.get_by(Component, clauses, opts) |> Repo.preload(:attrs)
  end

  @doc """
  List components by `name`.

  ## Example

      iex> list_components_by_name(site, "header")
      [%Component{name: "header"}]

  """
  @doc type: :components
  @spec list_components_by_name(Site.t(), String.t()) :: [Component.t()]
  def list_components_by_name(site, name) when is_atom(site) and is_binary(name) do
    Repo.all(
      from c in Component,
        where: c.site == ^site and c.name == ^name
    )
  end

  @doc """
  List components.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specfic page. Defaults to 1.
    * `:query` - search components by title. Defaults to `nil`, doesn't filter query.
    * `:preloads` - a list of preloads to load.
    * `:sort` - column in which the result will be ordered by. Defaults to `:name`.

  """
  @doc type: :components
  @spec list_components(Site.t(), keyword()) :: [Component.t()]
  def list_components(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :query)
    preloads = Keyword.get(opts, :preloads, [])
    sort = Keyword.get(opts, :sort, :name)

    site
    |> query_list_components_base()
    |> query_list_components_preloads(preloads)
    |> query_list_components_limit(per_page)
    |> query_list_components_offset(per_page, page)
    |> query_list_components_search(search)
    |> query_list_components_preloads(preloads)
    |> query_list_components_sort(sort)
    |> Repo.all()
  end

  defp query_list_components_base(site), do: from(l in Component, where: l.site == ^site)

  defp query_list_components_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_components_limit(query, :infinity = _limit), do: query
  defp query_list_components_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_list_components_offset(query, per_page, page) when is_integer(per_page) and is_integer(page) do
    offset = page * per_page - per_page
    from(q in query, offset: ^offset)
  end

  defp query_list_components_offset(query, _per_page, _page), do: from(q in query, offset: 0)

  defp query_list_components_search(query, search) when is_binary(search), do: from(q in query, where: ilike(q.name, ^"%#{search}%"))
  defp query_list_components_search(query, _search), do: query

  defp query_list_components_preloads(query, [_preload | _] = preloads), do: from(q in query, preload: ^preloads)
  defp query_list_components_preloads(query, _preloads), do: query

  defp query_list_components_sort(query, sort), do: from(q in query, order_by: [asc: ^sort])

  @doc """
  Counts the total number of components based on the amount of pages.

  ## Options
    * `:query` - filter rows count by query. Defaults to `nil`, doesn't filter query.

  """
  @doc type: :components
  @spec count_components(Site.t(), keyword()) :: non_neg_integer()
  def count_components(site, opts \\ []) do
    search = Keyword.get(opts, :query)

    site
    |> query_list_components_base()
    |> query_list_components_search(search)
    |> select([q], count(q.id))
    |> Repo.one()
  end

  # COMPONENT ATTR

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking component_attr changes.

  ## Example

      iex> change_component(component, %{name: "Header"})
      %Ecto.Changeset{data: %Component{}}

  """
  @doc type: :components
  @spec change_component_attr(ComponentAttr.t(), map()) :: Changeset.t()
  def change_component_attr(%ComponentAttr{} = component, attrs \\ %{}) do
    ComponentAttr.changeset(component, attrs)
  end

  # SNIPPETS

  @doc """
  Creates a snippet helper
  """
  @doc type: :snippets
  @spec create_snippet_helper(map()) :: {:ok, Snippets.Helper.t()} | {:error, Changeset.t()}
  def create_snippet_helper(attrs) do
    %Snippets.Helper{}
    |> Changeset.cast(attrs, [:site, :name, :body])
    |> Changeset.validate_required([:site, :name, :body])
    |> Changeset.unique_constraint([:site, :name])
    |> validate_snippet_helper()
    |> Repo.insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :snippet_helper))
  end

  defp validate_snippet_helper(changeset) do
    Changeset.validate_change(changeset, :body, fn :body, body ->
      case Solid.parse(body, parser: Snippets.Parser) do
        {:ok, _template} -> []
        {:error, error} -> [{:body, error.message}]
      end
    end)
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

      iex> Beacon.Content.render_snippet("title is {{ page.title }}", %{page: %{title: "home"}})
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

  Snippets can be used in:

    * Meta Tag value
    * Page Schema (structured Schema.org tags)
    * Page Title

  Allowed assigns:

    * :page (map)
    * :live_data (map)

  """
  @doc type: :snippets
  @spec render_snippet(String.t(), %{
          page: %{
            site: Beacon.Types.Site.t(),
            path: String.t(),
            title: String.t(),
            description: String.t(),
            meta_tags: [map()],
            raw_schema: Beacon.Types.JsonArrayMap.t(),
            order: integer(),
            format: atom(),
            extra: map()
          },
          live_data: map()
        }) :: {:ok, String.t()} | {:error, Beacon.SnippetError.t()}
  def render_snippet(template, assigns) when is_binary(template) and is_map(assigns) do
    page = Map.get(assigns, :page) || raise "expected assigns.page missing"
    live_data = Map.get(assigns, :live_data) || raise "expected assigns.live_data missing"

    assigns = %{
      "page" => deep_stringify(page),
      "live_data" => deep_stringify(live_data)
    }

    with {:ok, template} <- Solid.parse(template, parser: Snippets.Parser),
         {:ok, template} <- Solid.render(template, assigns) do
      {:ok, to_string(template)}
    else
      {:error, error} ->
        {:error, Beacon.SnippetError.exception(error)}

      error ->
        message = """
        failed to render the following snippet

        #{template}

        Got: #{inspect(error)}

        """

        {:error, Beacon.SnippetError.exception(message)}
    end
  end

  defp deep_stringify(struct) when is_struct(struct), do: deep_stringify(Map.from_struct(struct))
  defp deep_stringify(map) when is_map(map), do: Map.new(map, fn {k, v} -> {to_string(k), deep_stringify(v)} end)
  defp deep_stringify(non_map), do: non_map

  # ERROR PAGES

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking error page changes.

  ## Example

      iex> change_error_page(error_page, %{status: 404})
      %Ecto.Changeset{data: %ErrorPage{}}

  """
  @doc type: :error_pages
  @spec change_error_page(ErrorPage.t(), map()) :: Changeset.t()
  def change_error_page(%ErrorPage{} = error_page, attrs \\ %{}) do
    ErrorPage.changeset(error_page, attrs)
  end

  @doc """
  Returns the error page for a given site and status code, or `nil` if no matching error page exists.
  """
  @doc type: :error_pages
  @spec get_error_page(Site.t(), ErrorPage.error_status()) :: ErrorPage.t() | nil
  def get_error_page(site, status) do
    Repo.one(
      from e in ErrorPage,
        where: e.site == ^site,
        where: e.status == ^status
    )
  end

  @doc """
  Lists all error pages for a given site.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records.
    * `:preloads` - a list of preloads to load.

  """
  @doc type: :error_pages
  @spec list_error_pages(Site.t(), keyword()) :: [ErrorPage.t()]
  def list_error_pages(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    preloads = Keyword.get(opts, :preloads, [])

    site
    |> query_list_error_pages_base()
    |> query_list_error_pages_limit(per_page)
    |> query_list_error_pages_preloads(preloads)
    |> Repo.all()
  end

  @doc type: :error_pages
  @spec list_error_pages_by(Site.t(), keyword(), keyword()) :: Layout.t() | nil
  def list_error_pages_by(site, clauses, opts \\ []) when is_atom(site) and is_list(clauses) do
    per_page = Keyword.get(opts, :per_page, 20)
    preloads = Keyword.get(opts, :preloads, [])

    filter_layout_id =
      if layout_id = clauses[:layout_id] do
        dynamic([ep], ep.layout_id == ^layout_id)
      else
        true
      end

    site
    |> query_list_error_pages_base()
    |> query_list_error_pages_limit(per_page)
    |> query_list_error_pages_preloads(preloads)
    |> where(^filter_layout_id)
    |> Repo.all()
  end

  defp query_list_error_pages_base(site) do
    from p in ErrorPage,
      where: p.site == ^site,
      order_by: [asc: p.status]
  end

  defp query_list_error_pages_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_list_error_pages_limit(query, :infinity = _limit), do: query
  defp query_list_error_pages_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_list_error_pages_preloads(query, [_preload | _] = preloads) do
    from(q in query, preload: ^preloads)
  end

  defp query_list_error_pages_preloads(query, _preloads), do: query

  @doc """
  Creates a new error page.
  """
  @doc type: :error_pages
  @spec create_error_page(%{site: Site.t(), status: ErrorPage.error_status(), template: binary(), layout_id: Ecto.UUID.t()}) ::
          {:ok, ErrorPage.t()} | {:error, Changeset.t()}
  def create_error_page(attrs) do
    %ErrorPage{}
    |> ErrorPage.changeset(attrs)
    |> validate_error_page()
    |> Repo.insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :error_page))
  end

  @doc """
  Creates a new error page, raising if the operation fails.
  """
  @doc type: :error_pages
  @spec create_error_page!(%{site: Site.t(), status: ErrorPage.error_status(), template: binary(), layout_id: Ecto.UUID.t()}) ::
          ErrorPage.t()
  def create_error_page!(attrs) do
    case create_error_page(attrs) do
      {:ok, error_page} -> error_page
      {:error, changeset} -> raise "failed to create error page, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Returns attr data to load the default error_pages into new sites.
  """
  @spec default_error_pages() :: [map()]
  @doc type: :error_pages
  def default_error_pages do
    for status <- [404, 500] do
      %{
        status: status,
        template: Plug.Conn.Status.reason_phrase(status)
      }
    end
  end

  @doc """
  Updates an error page.
  """
  @doc type: :error_pages
  @spec update_error_page(ErrorPage.t(), map()) :: {:ok, ErrorPage.t()} | {:error, Changeset.t()}
  def update_error_page(error_page, attrs) do
    error_page
    |> ErrorPage.changeset(attrs)
    |> validate_error_page()
    |> Repo.update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :error_page))
  end

  @doc """
  Deletes an error page.
  """
  @doc type: :error_pages
  @spec delete_error_page(ErrorPage.t()) :: {:ok, ErrorPage.t()} | {:error, Changeset.t()}
  def delete_error_page(error_page) do
    Repo.delete(error_page)
  end

  defp validate_error_page(changeset) do
    template = Changeset.get_field(changeset, :template)
    site = Changeset.get_field(changeset, :site)
    status = Changeset.get_field(changeset, :status)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: "/_beacon_error_#{status}"}

    do_validate_template(changeset, :template, :heex, template, metadata)
  end

  # PAGE EVENT HANDLERS

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event handler changes.

  ## Example

      iex> change_page_event_handler(page_event_handler, %{name: "form-submit"})
      %Ecto.Changeset{data: %PageEventHandler{}}

  """
  @doc type: :page_event_handlers
  @spec change_page_event_handler(PageEventHandler.t(), map()) :: Changeset.t()
  def change_page_event_handler(%PageEventHandler{} = event_handler, attrs \\ %{}) do
    PageEventHandler.changeset(event_handler, attrs)
  end

  @doc """
  Creates a new page event handler and returns the page with updated `:event_handlers` association.
  """
  @doc type: :page_event_handlers
  @spec create_event_handler_for_page(Page.t(), %{name: binary(), code: binary()}) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def create_event_handler_for_page(page, attrs) do
    changeset =
      page
      |> Ecto.build_assoc(:event_handlers)
      |> PageEventHandler.changeset(attrs)
      |> validate_page_event_handler(page)

    Repo.transact(fn ->
      with {:ok, %PageEventHandler{}} <- Repo.insert(changeset),
           %Page{} = page <- Repo.preload(page, :event_handlers, force: true),
           %Page{} = page <- Lifecycle.Page.after_update_page(page) do
        {:ok, page}
      end
    end)
  end

  @doc """
  Updates a page event handler and returns the page with updated `:event_handlers` association.
  """
  @doc type: :page_event_handlers
  @spec update_event_handler_for_page(Page.t(), PageEventHandler.t(), map()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def update_event_handler_for_page(page, event_handler, attrs) do
    changeset =
      event_handler
      |> PageEventHandler.changeset(attrs)
      |> validate_page_event_handler(page)

    Repo.transact(fn ->
      with {:ok, %PageEventHandler{}} <- Repo.update(changeset),
           %Page{} = page <- Repo.preload(page, :event_handlers, force: true),
           %Page{} = page <- Lifecycle.Page.after_update_page(page) do
        {:ok, page}
      end
    end)
  end

  defp validate_page_event_handler(changeset, page) do
    code = Changeset.get_field(changeset, :code)
    metadata = %Beacon.Template.LoadMetadata{site: page.site, path: page.path}
    variable_names = ["socket", "event_params"]
    imports = ["Phoenix.Socket"]

    do_validate_template(changeset, :code, :elixir, code, metadata, variable_names, imports)
  end

  @doc """
  Deletes a page event handler and returns the page with updated `:event_handlers` association.
  """
  @doc type: :page_event_handlers
  @spec delete_event_handler_from_page(Page.t(), PageEventHandler.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def delete_event_handler_from_page(page, event_handler) do
    with {:ok, %PageEventHandler{}} <- Repo.delete(event_handler),
         %Page{} = page <- Repo.preload(page, :event_handlers, force: true),
         %Page{} = page <- Lifecycle.Page.after_update_page(page) do
      {:ok, page}
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
  @spec change_page_variant(PageVariant.t(), map()) :: Changeset.t()
  def change_page_variant(%PageVariant{} = variant, attrs \\ %{}) do
    PageVariant.changeset(variant, attrs)
  end

  @doc """
  Creates a new page variant and returns the page with updated `:variants` association.
  """
  @doc type: :page_variants
  @spec create_variant_for_page(Page.t(), %{name: binary(), template: binary(), weight: integer()}) ::
          {:ok, Page.t()} | {:error, Changeset.t()}
  def create_variant_for_page(page, attrs) do
    changeset =
      page
      |> Ecto.build_assoc(:variants)
      |> PageVariant.changeset(attrs)
      |> validate_variant(page)

    Repo.transact(fn ->
      with {:ok, %PageVariant{}} <- Repo.insert(changeset),
           %Page{} = page <- Repo.preload(page, :variants, force: true),
           %Page{} = page <- Lifecycle.Page.after_update_page(page) do
        {:ok, page}
      end
    end)
  end

  @doc """
  Updates a page variant and returns the page with updated `:variants` association.
  """
  @doc type: :page_variants
  @spec update_variant_for_page(Page.t(), PageVariant.t(), map()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def update_variant_for_page(page, variant, attrs) do
    changeset =
      variant
      |> PageVariant.changeset(attrs)
      |> validate_variant(page)

    Repo.transact(fn ->
      with {:ok, %PageVariant{}} <- Repo.update(changeset),
           %Page{} = page <- Repo.preload(page, :variants, force: true),
           %Page{} = page <- Lifecycle.Page.after_update_page(page) do
        {:ok, page}
      end
    end)
  end

  defp validate_variant(changeset, page) do
    %{format: format, site: site, path: path} = page = Repo.preload(page, :variants)
    template = Changeset.get_field(changeset, :template)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: path}

    changeset
    |> do_validate_weights(page)
    |> do_validate_template(:template, format, template, metadata)
  end

  defp do_validate_weights(changeset, page) do
    Changeset.validate_change(changeset, :weight, fn :weight, changed_weight ->
      %{id: changed_variant_id} = changeset.data

      total_weights =
        Enum.reduce(page.variants, 0, fn
          %{id: ^changed_variant_id}, acc -> acc + changed_weight
          variant, acc -> acc + variant.weight
        end)

      if total_weights > 100 do
        [weight: "total weights cannot exceed 100"]
      else
        []
      end
    end)
  end

  @doc """
  Deletes a page variant and returns the page with updated variants association.
  """
  @doc type: :page_variants
  @spec delete_variant_from_page(Page.t(), PageVariant.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def delete_variant_from_page(page, variant) do
    with {:ok, %PageVariant{}} <- Repo.delete(variant),
         %Page{} = page <- Repo.preload(page, :variants, force: true),
         %Page{} = page <- Lifecycle.Page.after_update_page(page) do
      {:ok, page}
    end
  end

  # LIVE DATA

  @doc """
  Returns a list of all existing LiveDataAssign formats.
  """
  @doc type: :live_data
  @spec live_data_assign_formats() :: [atom()]
  def live_data_assign_formats, do: LiveDataAssign.formats()

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking LiveData `:path` changes.

  ## Example

      iex> change_live_data(live_data, %{path: "/foo/:bar_id"})
      %Ecto.Changeset{data: %LiveData{}}

  """
  @doc type: :live_data
  @spec change_live_data_path(LiveData.t(), map()) :: Changeset.t()
  def change_live_data_path(%LiveData{} = live_data, attrs \\ %{}) do
    LiveData.path_changeset(live_data, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking LiveDataAssign changes.

  ## Example

      iex> change_live_data_assign(live_data_assign, %{format: :elixir, value: "Enum.random(1..100)"})
      %Ecto.Changeset{data: %LiveDataAssign{}}

  """
  @doc type: :live_data
  @spec change_live_data_assign(LiveDataAssign.t(), map()) :: Changeset.t()
  def change_live_data_assign(%LiveDataAssign{} = live_data_assign, attrs \\ %{}) do
    LiveDataAssign.changeset(live_data_assign, attrs)
  end

  @doc """
  Creates a new LiveData for scoping live data to pages.
  """
  @doc type: :live_data
  @spec create_live_data(map()) :: {:ok, LiveData.t()} | {:error, Changeset.t()}
  def create_live_data(attrs) do
    %LiveData{}
    |> LiveData.changeset(attrs)
    |> Repo.insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :live_data))
  end

  @doc """
  Creates a new LiveData for scoping live data to pages.
  """
  @doc type: :live_data
  @spec create_live_data!(map()) :: LiveData.t()
  def create_live_data!(attrs) do
    case create_live_data(attrs) do
      {:ok, live_data} -> live_data
      {:error, changeset} -> raise "failed to create live data, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Creates a new LiveDataAssign.
  """
  @doc type: :live_data
  @spec create_assign_for_live_data(LiveData.t(), map()) :: {:ok, LiveData.t()} | {:error, Changeset.t()}
  def create_assign_for_live_data(live_data, attrs) do
    changeset =
      live_data
      |> Ecto.build_assoc(:assigns)
      |> Map.put(:live_data, live_data)
      |> LiveDataAssign.changeset(attrs)
      |> validate_live_data_code()

    case Repo.insert(changeset) do
      {:ok, %LiveDataAssign{}} ->
        live_data = Repo.preload(live_data, :assigns, force: true)
        maybe_broadcast_updated_content_event({:ok, live_data}, :live_data)
        {:ok, live_data}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a single `LiveData` entry by `:id`.

  ## Example

      iex> get_live_data("5d5b228c-3a46-4e76-ab27-d3ed3f92ccea")
      %LiveData{}

  """
  @doc type: :live_data
  @spec get_live_data(binary()) :: LiveData.t() | nil
  def get_live_data(id) do
    Repo.one(
      from(ld in LiveData,
        where: ld.id == ^id,
        preload: :assigns
      )
    )
  end

  @doc """
  Gets a single `LiveData` entry by `:site` and `:path`.

  ## Example

      iex> get_live_data(:my_site, "/foo/bar/:baz")
      %LiveData{}

  """
  @doc type: :live_data
  @spec get_live_data(Site.t(), String.t()) :: LiveData.t() | nil
  def get_live_data(site, path) do
    LiveData
    |> Repo.get_by(site: site, path: path)
    |> Repo.preload(:assigns)
  end

  @doc """
  Query LiveData for a given site.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records.
    * `:query` - search records by path.
    * `:select` - returns only the given field(s)
    * `:preload` - include given association(s) (defaults to `:assigns`)

  """
  @doc type: :live_data
  @spec live_data_for_site(Site.t(), Keyword.t()) :: [String.t()]
  def live_data_for_site(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, :infinity)
    search = Keyword.get(opts, :query)
    select = Keyword.get(opts, :select)
    preload = Keyword.get(opts, :preload, :assigns)

    site
    |> query_live_data_for_site_base()
    |> query_live_data_for_site_limit(per_page)
    |> query_live_data_for_site_search(search)
    |> query_live_data_for_site_select(select)
    |> query_live_data_for_site_preload(preload)
    |> Repo.all()
  end

  defp query_live_data_for_site_base(site) do
    from ld in LiveData,
      where: ld.site == ^site,
      order_by: [asc: ld.path]
  end

  defp query_live_data_for_site_limit(query, limit) when is_integer(limit), do: from(q in query, limit: ^limit)
  defp query_live_data_for_site_limit(query, :infinity = _limit), do: query
  defp query_live_data_for_site_limit(query, _per_page), do: from(q in query, limit: 20)

  defp query_live_data_for_site_search(query, search) when is_binary(search), do: from(q in query, where: ilike(q.path, ^"%#{search}%"))
  defp query_live_data_for_site_search(query, _search), do: query

  defp query_live_data_for_site_select(query, nil = _select), do: query
  defp query_live_data_for_site_select(query, select), do: from(q in query, select: ^select)

  defp query_live_data_for_site_preload(query, nil), do: query
  defp query_live_data_for_site_preload(query, preload) when is_atom(preload) or is_list(preload), do: from(q in query, preload: ^preload)

  @doc """
  Updates LiveDataPath.

      iex> update_live_data_path(live_data, "/foo/bar/:baz_id")
      {:ok, %LiveData{}}

  """
  @doc type: :live_data
  @spec update_live_data_path(LiveData.t(), String.t()) :: {:ok, LiveData.t()} | {:error, Changeset.t()}
  def update_live_data_path(%LiveData{} = live_data, path) do
    live_data
    |> LiveData.path_changeset(%{path: path})
    |> Repo.update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :live_data))
  end

  @doc """
  Updates LiveDataAssign.

      iex> update_live_data_assign(live_data_assign, %{code: "true"})
      {:ok, %LiveDataAssign{}}

  """
  @doc type: :live_data
  @spec update_live_data_assign(LiveDataAssign.t(), map()) :: {:ok, LiveDataAssign.t()} | {:error, Changeset.t()}
  def update_live_data_assign(%LiveDataAssign{} = live_data_assign, attrs) do
    live_data_assign
    |> Repo.preload(:live_data)
    |> LiveDataAssign.changeset(attrs)
    |> validate_live_data_code()
    |> Repo.update()
    |> tap(fn
      {:ok, live_data_assign} -> maybe_broadcast_updated_content_event({:ok, live_data_assign.live_data}, :live_data)
      _error -> :skip
    end)
  end

  defp validate_live_data_code(changeset) do
    site = Changeset.get_field(changeset, :site)
    value = Changeset.get_field(changeset, :value)
    format = Changeset.get_field(changeset, :format)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: "nopath"}

    variable_names =
      changeset
      |> Changeset.get_field(:live_data)
      |> Map.fetch!(:path)
      |> vars_from_path()
      |> List.insert_at(0, "params")

    do_validate_template(changeset, :value, format, value, metadata, variable_names)
  end

  defp vars_from_path(path) do
    path
    |> String.split("/")
    |> Enum.filter(&String.starts_with?(&1, ":"))
    |> Enum.map(&String.slice(&1, 1..-1//1))
  end

  @doc """
  Deletes LiveData.
  """
  @doc type: :live_data
  @spec delete_live_data(LiveData.t()) :: {:ok, LiveData.t()} | {:error, Changeset.t()}
  def delete_live_data(live_data) do
    Repo.delete(live_data)
  end

  @doc """
  Deletes LiveDataAssign.
  """
  @doc type: :live_data
  @spec delete_live_data_assign(LiveDataAssign.t()) :: {:ok, LiveDataAssign.t()} | {:error, Changeset.t()}
  def delete_live_data_assign(live_data_assign) do
    Repo.delete(live_data_assign)
  end

  ## Utils

  defp do_validate_template(changeset, field, format, template, metadata, vars \\ [], imports \\ [])

  defp do_validate_template(changeset, field, _format, nil = _template, _metadata, _, _) do
    Changeset.add_error(changeset, field, "can't be blank", compilation_error: nil)
  end

  defp do_validate_template(changeset, field, :heex = _format, template, metadata, _, _) when is_binary(template) do
    Changeset.validate_change(changeset, field, fn ^field, template ->
      case Beacon.Template.HEEx.compile(metadata.site, metadata.path, template) do
        {:ok, _ast} -> []
        {:error, %{description: description}} -> [{field, {"invalid", compilation_error: description}}]
        {:error, %_{} = exception} -> [{field, {"invalid", compilation_error: Exception.message(exception)}}]
        {:error, _} -> [{field, "invalid"}]
      end
    end)
  end

  defp do_validate_template(changeset, field, :markdown = _format, template, metadata, _, _) when is_binary(template) do
    Changeset.validate_change(changeset, field, fn ^field, template ->
      case Beacon.Template.Markdown.convert_to_html(template, metadata) do
        {:cont, _template} -> []
        {:halt, %{message: message}} -> [{field, message}]
      end
    end)
  end

  defp do_validate_template(changeset, field, :elixir = _format, code, _metadata, vars, imports) when is_binary(code) do
    Changeset.validate_change(changeset, field, fn ^field, template ->
      case validate_elixir_code(template, vars, imports) do
        :ok -> []
        {:error, reason, message} -> [{field, {reason, compilation_error: message}}]
      end
    end)
  end

  defp do_validate_template(changeset, _field, :text = _format, _template, _metadata, _, _), do: changeset

  # TODO: expose template validation to custom template formats defined by users
  defp do_validate_template(changeset, _field, _format, _template, _metadata, _, _), do: changeset

  defp validate_elixir_code(code, vars, imports) do
    Application.put_env(:elixir, :ansi_enabled, false)

    full_code =
      "fn #{Enum.join(vars, ", ")} ->\n" <>
        Enum.map_join(imports, &"  import #{&1}\n") <>
        code <>
        "\nend"

    {compilation, diagnostics} =
      with_diagnostics(fn ->
        try do
          Code.compile_string(full_code)
          :ok
        rescue
          error -> {:error, error}
        end
      end)

    result =
      case compilation do
        :ok ->
          :ok

        {:error, error} ->
          message = "#{Exception.message(error)}\n\n#{diagnostic(diagnostics)}"
          {:error, "invalid", message}
      end

    Application.put_env(:elixir, :ansi_enabled, true)
    result
  end

  defp diagnostic([%{message: message} | _]), do: message
  defp diagnostic(_diagnostics), do: ""

  # extract elixir code diagnostics
  # https://github.com/elixir-lang/elixir/blob/38a571b73a59b72b34a6d70501b3e20bda34ae0e/lib/elixir/lib/code.ex#L611
  # TODO: remove this function after we required Elixir v1.15+
  defp with_diagnostics(opts \\ [], fun) do
    value = :erlang.get(:elixir_code_diagnostics)
    log = Keyword.get(opts, :log, false)
    :erlang.put(:elixir_code_diagnostics, {[], log})

    try do
      result = fun.()
      {diagnostics, _log?} = :erlang.get(:elixir_code_diagnostics)
      {result, Enum.reverse(diagnostics)}
    after
      if value == :undefined do
        :erlang.erase(:elixir_code_diagnostics)
      else
        :erlang.put(:elixir_code_diagnostics, value)
      end
    end
  end

  @doc false
  def handle_call({:publish_page, page}, _from, config) do
    %{site: site} = config

    publish = fn page ->
      changeset = Page.update_changeset(page, %{})

      Repo.transact(fn ->
        with {:ok, _changeset} <- validate_page_template(changeset),
             {:ok, event} <- create_page_event(page, "published"),
             {:ok, _snapshot} <- create_page_snapshot(page, event),
             %Page{} = page <- Lifecycle.Page.after_publish_page(page),
             :ok <- Beacon.RouterServer.add_page(page.site, page.id, page.path),
             true <- :ets.delete(table_name(site), page.id) do
          {:ok, page}
        end
      end)
    end

    with {:ok, page} <- publish.(page),
         :ok <- Beacon.PubSub.page_published(page) do
      {:reply, {:ok, page}, config}
    else
      error -> {:reply, error, config}
    end
  end

  @doc false
  def handle_call({:publish_layout, layout}, _from, config) do
    %{site: site} = config

    publish = fn layout ->
      changeset = Layout.changeset(layout, %{})

      Repo.transact(fn ->
        with {:ok, _changeset} <- validate_layout_template(changeset),
             {:ok, event} <- create_layout_event(layout, "published"),
             {:ok, _snapshot} <- create_layout_snapshot(layout, event),
             true <- :ets.delete(table_name(site), layout.id) do
          {:ok, layout}
        end
      end)
    end

    with {:ok, layout} <- publish.(layout),
         :ok <- Beacon.PubSub.layout_published(layout) do
      {:reply, {:ok, layout}, config}
    else
      error -> {:reply, error, config}
    end
  end

  @doc false
  def handle_call({:fetch_cached_content, id, fun}, _from, config) do
    %{site: site} = config
    match = {id, :_}
    guards = []
    body = [:"$_"]

    cache = fn id, fun ->
      case fun.() do
        nil ->
          nil

        content ->
          :ets.insert(table_name(site), {id, content})
          content
      end
    end

    content =
      case :ets.select(table_name(site), [{match, guards, body}]) do
        [{_id, content}] -> content
        _ -> cache.(id, fun)
      end

    {:reply, content, config}
  end

  @doc false
  def handle_call(:dump_cached_content, _from, config) do
    content = config.site |> table_name() |> :ets.match(:"$1") |> List.flatten()
    {:reply, content, config}
  end

  @doc false
  def handle_info(msg, config) do
    Logger.warning("Beacon.Content can not handle the message: #{inspect(msg)}")
    {:noreply, config}
  end
end
