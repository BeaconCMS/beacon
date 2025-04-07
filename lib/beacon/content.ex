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

  @doc false
  use GenServer

  import Ecto.Query
  import Beacon.Utils, only: [repo: 1, transact: 2]

  alias Beacon.Content.Component
  alias Beacon.Content.ComponentAttr
  alias Beacon.Content.ComponentSlot
  alias Beacon.Content.ComponentSlotAttr
  alias Beacon.Content.ErrorPage
  alias Beacon.Content.EventHandler
  alias Beacon.Content.InfoHandler
  alias Beacon.Content.JSHook
  alias Beacon.Content.Layout
  alias Beacon.Content.LayoutEvent
  alias Beacon.Content.LayoutSnapshot
  alias Beacon.Content.LiveData
  alias Beacon.Content.LiveDataAssign
  alias Beacon.Content.Page
  alias Beacon.Content.PageEvent
  alias Beacon.Content.PageField
  alias Beacon.Content.PageSnapshot
  alias Beacon.Content.PageVariant
  alias Beacon.Content.Snippets
  alias Beacon.Content.Stylesheet
  alias Beacon.Lifecycle
  alias Beacon.Types.Site
  alias Ecto.Changeset
  alias Ecto.UUID

  require Logger

  @doc false
  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  @doc false
  def table_name(site) do
    String.to_atom("beacon_content_#{site}")
  end

  defp clear_cache(site, key) do
    :ets.delete(table_name(site), key)
    :ok
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
    site = Changeset.get_field(changeset, :site)

    transact(repo(site), fn ->
      with {:ok, changeset} <- validate_layout_template(changeset),
           {:ok, layout} <- repo(site).insert(changeset),
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
    site = Changeset.get_field(changeset, :site)

    with {:ok, changeset} <- validate_layout_template(changeset) do
      repo(site).update(changeset)
    end
  end

  # TODO: only publish if there were actual changes compared to the last snapshot
  @doc """
  Publishes `layout` and reload resources to render the updated layout and pages.

  Event + snapshot

  This operation is serialized.
  """
  @doc type: :layouts
  @spec publish_layout(Layout.t()) :: {:ok, Layout.t()} | {:error, Changeset.t() | term()}
  def publish_layout(%Layout{} = layout) do
    case Beacon.Config.fetch!(layout.site).mode do
      :live ->
        GenServer.call(name(layout.site), {:publish_layout, layout})

      :testing ->
        layout
        |> insert_published_layout()
        |> tap(fn {:ok, layout} -> reset_published_layout(layout.site, layout.id) end)

      :manual ->
        insert_published_layout(layout)
    end
  end

  @doc """
  Same as `publish_layout/2` but accepts a `site` and `layout_id` with which to lookup the layout.
  """
  @doc type: :layouts
  @spec publish_layout(Site.t(), UUID.t()) :: {:ok, Layout.t()} | any()
  def publish_layout(site, layout_id) when is_atom(site) and is_binary(layout_id) do
    site
    |> get_layout(layout_id)
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
    |> repo(layout).insert()
  end

  @doc false
  def create_layout_snapshot(layout, event) do
    attrs = %{"site" => layout.site, "schema_version" => Layout.version(), "layout_id" => layout.id, "layout" => layout, "event_id" => event.id}

    %LayoutSnapshot{}
    |> Changeset.cast(attrs, [:site, :schema_version, :layout_id, :layout, :event_id])
    |> Changeset.validate_required([:site, :schema_version, :layout_id, :layout, :event_id])
    |> repo(layout).insert()
  end

  @doc """
  Gets a single layout by `id`.

  ## Example

      iex> get_layout(:my_site, "fd70e5fe-9bd8-41ed-94eb-5459c9bb05fc")
      %Layout{}

  """
  @doc type: :layouts
  @spec get_layout(Site.t(), UUID.t()) :: Layout.t() | nil
  def get_layout(site, id) when is_atom(site) and is_binary(id) do
    repo(site).get(Layout, id)
  end

  @doc """
  Same as `get_layout/2` but raises an error if no result is found.
  """
  @doc type: :layouts
  @spec get_layout!(Site.t(), UUID.t()) :: Layout.t()
  def get_layout!(site, id) when is_atom(site) and is_binary(id) do
    repo(site).get!(Layout, id)
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
    repo(site).get_by(Layout, clauses, opts)
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
  @spec list_layout_events(Site.t(), UUID.t()) :: [LayoutEvent.t()]
  def list_layout_events(site, layout_id) when is_atom(site) and is_binary(layout_id) do
    repo(site).all(
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
    repo(site).one(
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
    * `:page` - returns records from a specific page. Defaults to 1.
    * `:query` - search layouts by title. Defaults to `nil`, doesn't filter query.
    * `:preloads` - a list of preloads to load.
    * `:sort` - column in which the result will be ordered by. Defaults to `:title`.
      Allowed values: `:title`, `:template`, `:meta_tags`, `:resource_links`, `:inserted_at`, `:updated_at`.

  """
  @doc type: :layouts
  @spec list_layouts(Site.t(), keyword()) :: [Layout.t()]
  def list_layouts(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :query)
    preloads = Keyword.get(opts, :preloads, [])
    sort = Keyword.get(opts, :sort)
    sort = if sort in [:title, :template, :meta_tags, :resource_links, :inserted_at, :updated_at], do: sort, else: :title

    site
    |> query_list_layouts_base()
    |> query_list_layouts_limit(per_page)
    |> query_list_layouts_offset(per_page, page)
    |> query_list_layouts_search(search)
    |> query_list_layouts_preloads(preloads)
    |> query_list_layouts_sort(sort)
    |> repo(site).all()
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
    |> repo(site).one()
  end

  @doc """
  Returns all published layouts for `site`.

  Layouts are extracted from the latest published `Beacon.Content.LayoutSnapshot`.
  """
  @doc type: :layouts
  @spec list_published_layouts(Site.t()) :: [Layout.t()]
  def list_published_layouts(site) do
    repo(site).all(
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
  @spec get_published_layout(Site.t(), UUID.t()) :: Layout.t() | nil
  def get_published_layout(site, layout_id) do
    get_fun = fn ->
      repo(site).one(
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

    {:ok, site} = Beacon.Types.Site.cast(attrs["site"])
    changeset = Page.create_changeset(%Page{}, maybe_put_default_meta_tags(site, attrs))

    transact(repo(site), fn ->
      with {:ok, changeset} <- validate_page_template(changeset),
           {:ok, page} <- repo(site).insert(changeset),
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

  Raises an error if unsuccessful.
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
    changeset = Page.update_changeset(page, attrs)

    transact(repo(page), fn ->
      with {:ok, changeset} <- validate_page_template(changeset),
           {:ok, page} <- repo(page.site).update(changeset),
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
    case Beacon.Config.fetch!(page.site).mode do
      :live ->
        GenServer.call(name(page.site), {:publish_page, page})

      :testing ->
        page
        |> insert_published_page()
        |> tap(fn {:ok, page} -> reset_published_page(page.site, page.id) end)

      :manual ->
        insert_published_page(page)
    end
  end

  @doc """
  Same as `publish_page/1` but accepts a `site` and `page_id` with which to lookup the page.
  """
  @doc type: :pages
  @spec publish_page(Site.t(), UUID.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def publish_page(site, page_id) when is_atom(site) and is_binary(page_id) do
    site
    |> get_page(page_id)
    |> publish_page()
  end

  # TODO: only publish if there were actual changes compared to the last snapshot
  @doc """
  Publish multiple `pages`.

  Similar to `publish_page/1` but defers loading dependent resources
  as late as possible making the process faster.
  """
  @doc type: :pages
  @spec publish_pages([Page.t()]) :: {:ok, [Page.t()]}
  def publish_pages(pages) when is_list(pages) do
    publish = fn page ->
      transact(repo(page), fn ->
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

  The page will be removed from your site and it will return error 404 for new requests.

  This operation is serialized.
  """
  @doc type: :pages
  @spec unpublish_page(Page.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def unpublish_page(%Page{} = page) do
    case Beacon.Config.fetch!(page.site).mode do
      :live ->
        GenServer.call(name(page.site), {:unpublish_page, page})

      :testing ->
        page
        |> insert_unpublished_page()
        |> tap(fn {:ok, page} -> clear_cache(page.site, page.id) end)

      :manual ->
        insert_unpublished_page(page)
    end
  end

  @doc false
  def create_page_event(page, event) do
    attrs = %{"site" => page.site, "page_id" => page.id, "event" => event}

    %PageEvent{}
    |> Changeset.cast(attrs, [:site, :page_id, :event])
    |> Changeset.validate_required([:site, :page_id, :event])
    |> repo(page).insert()
  end

  @doc false
  def create_page_snapshot(page, event) do
    page = repo(page).preload(page, :variants)

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
    |> repo(page).insert()
  end

  @doc """
  Gets a single page by `id`.

  ## Options

    * `:preloads` - a list of preloads to load.

  ## Examples

      iex> get_page(:my_site, "dba8a99e-311a-4806-af04-dd968c7e5dae")
      %Page{}

      iex> get_page(:my_site, "dba8a99e-311a-4806-af04-dd968c7e5dae", preloads: [:layout])
      %Page{layout: %Layout{}}

  """
  @doc type: :pages
  @spec get_page(Site.t(), UUID.t(), keyword()) :: Page.t() | nil
  def get_page(site, id, opts \\ []) when is_atom(site) and is_binary(id) and is_list(opts) do
    preloads = Keyword.get(opts, :preloads, [])

    Page
    |> repo(site).get(id)
    |> repo(site).preload(preloads)
  end

  @doc """
  Same as `get_page/3` but raises an error if no result is found.
  """
  @doc type: :pages
  @spec get_page!(Site.t(), UUID.t(), keyword()) :: Page.t()
  def get_page!(site, id, opts \\ []) when is_atom(site) and is_binary(id) and is_list(opts) do
    case get_page(site, id, opts) do
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
    repo(site).get_by(Page, clauses, opts)
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
  @spec list_page_events(Site.t(), UUID.t()) :: [PageEvent.t()]
  def list_page_events(site, page_id) when is_atom(site) and is_binary(page_id) do
    repo(site).all(
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
  @spec get_latest_page_event(Site.t(), UUID.t()) :: PageEvent.t() | nil
  def get_latest_page_event(site, page_id) when is_atom(site) and is_binary(page_id) do
    repo(site).one(
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
    * `:page` - returns records from a specific page. Defaults to 1.
    * `:query` - search pages by path or title.
    * `:preloads` - a list of preloads to load.
    * `:sort` - column in which the result will be ordered by. Defaults to `:path`.
      Allowed values: `:path`, `:title`, `:description`, `:template`, `:meta_tags`, `:raw_schema`, `:format`, `:inserted_at`, `:updated_at`.

  """
  @doc type: :pages
  @spec list_pages(Site.t(), keyword()) :: [Page.t()]
  def list_pages(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 20)
    page = Keyword.get(opts, :page, 1)
    search = Keyword.get(opts, :query)
    preloads = Keyword.get(opts, :preloads, [])
    sort = Keyword.get(opts, :sort)
    sort = if sort in [:path, :title, :description, :template, :meta_tags, :raw_schema, :format, :inserted_at, :updated_at], do: sort, else: :path

    site
    |> query_list_pages_base()
    |> query_list_pages_limit(per_page)
    |> query_list_pages_offset(per_page, page)
    |> query_list_pages_search(search)
    |> query_list_pages_preloads(preloads)
    |> query_list_pages_sort(sort)
    |> repo(site).all()
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
    |> repo(site).one()
  end

  @doc """
  Lists and search all published pages for `site`.

  Note that unpublished pages are not returned even if it was once published before, only the latest snapshot is considered.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specific page. Defaults to 1.
    * `:search` - search by either one or more fields or dynamic query function. Available fields: `path`, `title`, `format`, `extra`. Defaults to `nil` (do not apply search filter).
    * `:sort` - column or keyword in which the result will be ordered by. Defaults to `:title`.

  ## Examples

      iex> list_published_pages(:my_site, search: %{path: "/home", title: "Home Page"})
      [%Page{}]

      iex> list_published_pages(:my_site, search: %{extra: %{"tags" => "press"}})
      [%Page{}]

      iex> list_published_pages(:my_site, search: fn -> dynamic([q], fragment("extra->>'tags' ilike 'year-20%'")) end)
      [%Page{}]

      iex> list_published_pages(:my_site, sort: [desc: :path])
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
    |> repo(site).all()
    |> Enum.map(&extract_page_snapshot/1)
  end

  @doc """
  Similar to `list_published_pages/2`, but does not accept any options.  Instead, provide a list
  of paths, and this function will return any published pages which match one of those paths.
  """
  @doc type: :pages
  @spec list_published_pages_for_paths(Site.t(), [String.t()]) :: [Page.t()]
  def list_published_pages_for_paths(site, paths) do
    site
    |> query_list_published_pages_base()
    |> then(fn query -> from(q in query, where: q.path in ^paths) end)
    |> repo(site).all()
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

  defp query_list_published_pages_sort(query, {:length, key}), do: from(q in query, order_by: [{:asc, fragment("length(?)", field(q, ^key))}])
  defp query_list_published_pages_sort(query, sort) when is_list(sort), do: from(q in query, order_by: ^sort)
  defp query_list_published_pages_sort(query, sort), do: from(q in query, order_by: [asc: ^sort])

  @doc """
  Get latest published page.

  This operation is cached.
  """
  @doc type: :pages
  @spec get_published_page(Site.t(), UUID.t()) :: Page.t() | nil
  def get_published_page(site, page_id) do
    get_fun = fn ->
      events =
        from event in PageEvent,
          where: event.site == ^site,
          where: event.page_id == ^page_id,
          distinct: [asc: event.page_id],
          order_by: [desc: event.inserted_at]

      repo(site).one(
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
    |> repo(page).reload()
    |> repo(page).preload([:variants], force: true)
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(%{schema_version: 2, page: %Page{} = page}) do
    page
    |> repo(page).reload()
    |> repo(page).preload([:variants], force: true)
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
  Given a map of fields, stores this map as `:extra` fields in a `Page`.

  Any existing `:extra` data for that Page will be overwritten!
  """
  @doc type: :pages
  @spec put_page_extra(Page.t(), map()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def put_page_extra(%Page{} = page, attrs) when is_map(attrs) do
    attrs = %{"extra" => attrs}

    page
    |> Changeset.cast(attrs, [:extra])
    |> repo(page).update()
  end

  @doc """
  Returns the list of meta tags that are applied to all pages by default.

  These meta tags can be overwritten or extended on a Layout or Page level.
  """
  @spec default_site_meta_tags() :: [map()]
  @doc type: :pages
  def default_site_meta_tags do
    [
      %{"charset" => "utf-8"},
      %{"http-equiv" => "X-UA-Compatible", "content" => "IE=edge"},
      %{"name" => "viewport", "content" => "width=device-width, initial-scale=1"}
    ]
  end

  # STYLESHEETS

  @doc """
  Creates a stylesheet.

  Returns `{:ok, stylesheet}` if successful, otherwise `{:error, changeset}`.

  ## Example

      iex> create_stylesheet(%{
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
    changeset = Stylesheet.changeset(%Stylesheet{}, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> repo(site).insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :stylesheet))
  end

  @doc """
  Creates a stylesheet, raising an error if unsuccessful.

  Returns the new stylesheet if successful, otherwise raises a `RuntimeError`.

  ## Example

      iex> create_stylesheet!(%{
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
      %Stylesheet{}

  Note that escape characters must be preserved, so you should use `~S` to avoid issues.
  """
  @doc type: :stylesheets
  @spec create_stylesheet!(map()) :: Stylesheet.t()
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
    |> repo(stylesheet).update()
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
    repo(site).get_by(Stylesheet, clauses, opts)
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
    repo(site).all(
      from s in Stylesheet,
        where: s.site == ^site
    )
  end

  # JS HOOKS

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking JS Hook changes.

  ## Example

      iex> change_js_hook(js_hook, %{name: "MyCustomHook"})
      %Ecto.Changeset{data: %JSHook{}}

  """
  @doc type: :js_hooks
  @spec change_js_hook(JSHook.t(), map()) :: Changeset.t()
  def change_js_hook(%JSHook{} = js_hook, attrs \\ %{}) do
    JSHook.changeset(js_hook, attrs)
  end

  @doc """
  Creates a JS Hook.

  Returns `{:ok, js_hook}` if successful, otherwise `{:error, changeset}`.

  ## Example

      iex> code = "export const ConsoleLogHook = {mounted() {console.log(\"foo\")}}"
      iex> create_js_hook(%{site: :my_site, name: "ConsoleLogHook", code: code})
      {:ok, %JSHook{}}

  """
  @doc type: :js_hooks
  @spec create_js_hook(map()) :: {:ok, JSHook.t()} | {:error, Changeset.t()}
  def create_js_hook(attrs) do
    changeset = JSHook.changeset(%JSHook{}, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> repo(site).insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :js_hook))
  end

  @doc """
  Creates a JS Hook, raising an error if unsuccessful.
  """
  @doc type: :js_hooks
  @spec create_js_hook!(map()) :: JSHook.t()
  def create_js_hook!(attrs) do
    case create_js_hook(attrs) do
      {:ok, js_hook} -> js_hook
      {:error, changeset} -> raise "failed to create JS Hook, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Generates an empty Hook template for the given name.
  """
  @doc type: :js_hooks
  @spec default_hook_code(String.t()) :: String.t()
  def default_hook_code(name) do
    """
    export const #{name} = {
      mounted() {

      },
      beforeUpdate() {

      },
      updated() {

      },
      destroyed() {

      },
      disconnected() {

      },
      reconnected() {

      },
    };
    """
  end

  @doc """
  Gets a single JS hooks by `clauses`.

  ## Example

      iex> get_component_by(site, name: "CloseOnGlobalClick")
      %JSHook{}

  """
  @doc type: :js_hooks
  @spec get_js_hook_by(Site.t(), keyword(), keyword()) :: JSHook.t() | nil
  def get_js_hook_by(site, clauses, opts \\ []) when is_atom(site) and is_list(clauses) do
    clauses = Keyword.put(clauses, :site, site)
    repo(site).get_by(JSHook, clauses, opts)
  end

  @doc """
  Lists all JS Hooks for a site.
  """
  @doc type: :js_hooks
  @spec list_js_hooks(Site.t()) :: [JSHook.t()]
  def list_js_hooks(site) do
    repo(site).all(from h in JSHook, where: h.site == ^site)
  end

  @doc """
  Updates a JS Hook.
  """
  @doc type: :js_hooks
  @spec update_js_hook(JSHook.t(), map()) :: {:ok, JSHook.t()} | {:error, Changeset.t()}
  def update_js_hook(js_hook, attrs) do
    js_hook
    |> JSHook.changeset(attrs)
    |> repo(js_hook).update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :js_hook))
  end

  @doc """
  Deletes a JS Hook.
  """
  @doc type: :js_hooks
  @spec delete_js_hook(JSHook.t()) :: {:ok, JSHook.t()} | {:error, Changeset.t()}
  def delete_js_hook(js_hook) do
    js_hook
    |> repo(js_hook).delete()
    |> tap(&maybe_broadcast_updated_content_event(&1, :js_hook))
  end

  # COMPONENTS

  @doc false
  #  Returns the list of components that are loaded by default into new sites.
  @spec blueprint_components() :: [map()]
  def blueprint_components do
    components =
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
          example: ~S|<.page_link path={~p"/contact"} class="text-xl">Contact Us</.page_link>|,
          category: :element
        },
        %{
          name: "heroicon",
          description: "Renders a Heroicon",
          thumbnail: "https://placehold.co/400x75?text=heroicon",
          attrs: [
            %{name: "name", type: "string", opts: [required: true]},
            %{name: "outline", type: "boolean", opts: [default: true]},
            %{name: "solid", type: "boolean", opts: [default: false]},
            %{name: "mini", type: "boolean", opts: [default: false]},
            %{name: "micro", type: "boolean", opts: [default: false]},
            %{name: "rest", type: "global", opts: [include: ~w(fill stroke stroke-width)]}
          ],
          body:
            ~S"""
            sizing =
              cond do
                assigns.micro -> "h-4 w-4"
                assigns.mini -> "h-5 w-5"
                :default -> "h-6 w-6"
              end

            icon =
              assigns.name
              |> String.replace("-", "_")
              |> String.to_atom()

            component = Function.capture(Beacon.Heroicons, icon, 1)

            {_, assigns} = get_and_update_in(assigns, [:rest, :class], fn current ->
              current = current || ""
              new = "#{current} #{sizing} align-middle inline-block"
              {current, new}
            end)

            assigns = assign(assigns, component: component)
            """
            |> String.trim(),
          template:
            ~S|<%= Phoenix.LiveView.TagEngine.component(@component, assigns, {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}) %>|,
          example: ~S|<.heroicon name="light-bulb" solid />|,
          category: :element
        },
        %{
          name: "button",
          description: "Renders a button",
          thumbnail: "https://placehold.co/400x75?text=button",
          attrs: [
            %{name: "type", type: "string", opts: [default: nil]},
            %{name: "rest", type: "global", opts: [include: ~w(disabled form name value)]}
          ],
          slots: [
            %{name: "inner_block", opts: [required: true]}
          ],
          template:
            ~S"""
            <button
              type={@type}
              class="phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80",
              {@rest}
            >
              <%= render_slot(@inner_block) %>
            </button>
            """
            |> String.trim(),
          example: ~S|<.button phx-click="go">Send!</.button>|,
          category: :element
        },
        %{
          name: "error",
          description: "Generates a generic error message",
          thumbnail: "https://placehold.co/400x75?text=error",
          slots: [
            %{name: "inner_block", opts: [required: true]}
          ],
          template:
            ~S"""
            <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
              <%= render_slot(@inner_block) %>
            </p>
            """
            |> String.trim(),
          example: ~S|<.error><p>Something went wrong</p></.error>|,
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
          body:
            ~S"""
            assigns =
                with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
                  assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
                end
            """
            |> String.trim(),
          template:
            ~S"""
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
            """
            |> String.trim(),
          example:
            ~S"""
            <.table id="users" rows={[%{id: 1, username: "admin"}]}>
              <:col :let={user} label="id"><%= user.id %></:col>
              <:col :let={user} label="username"><%= user.username %></:col>
            </.table>
            """
            |> String.trim(),
          category: :element
        },
        %{
          name: "simple_form",
          description: "Renders a simple form",
          thumbnail: "https://placehold.co/400x75?text=simple_form",
          attrs: [
            %{name: "for", type: "any", opts: [required: true]},
            %{name: "as", type: "any", opts: [default: nil]},
            %{name: "rest", type: "global", opts: [include: ~w(autocomplete name rel action enctype method novalidate target multipart)]}
          ],
          slots: [
            %{name: "inner_block", opts: [required: true]},
            %{name: "actions"}
          ],
          template:
            ~S"""
            <.form :let={f} for={@for} as={@as} {@rest}>
              <div class="mt-10 space-y-8 bg-white">
                <%= render_slot(@inner_block, f) %>
                <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
                  <%= render_slot(action, f) %>
                </div>
              </div>
            </.form>
            """
            |> String.trim(),
          example:
            ~S"""
            <.simple_form :let={f} for={%{}} as={:newsletter} phx-submit="join">
              <.input field={f[:name]} label="Name"/>
              <.input field={f[:email]} label="Email"/>
              <:actions>
                <.button>Join</.button>
              </:actions>
            </.simple_form>
            """
            |> String.trim(),
          category: :element
        },
        %{
          name: "input",
          description: "Renders an input with label and error messages",
          thumbnail: "https://placehold.co/400x75?text=input",
          attrs: [
            %{name: "id", type: "any", opts: [default: nil]},
            %{name: "name", type: "any"},
            %{name: "label", type: "string", opts: [default: nil]},
            %{name: "value", type: "any"},
            %{
              name: "type",
              type: "string",
              opts: [
                default: "text",
                values: ~w(checkbox color date datetime-local email file month number password range search select tel text textarea time url week)
              ]
            },
            %{name: "field", type: "struct", struct_name: "Phoenix.HTML.FormField", opts: [default: nil]},
            %{name: "errors", type: "list", opts: [default: []]},
            %{name: "checked", type: "boolean"},
            %{name: "prompt", type: "string", opts: [default: nil]},
            %{name: "options", type: "list"},
            %{name: "multiple", type: "boolean", opts: [default: false]},
            %{
              name: "rest",
              type: "global",
              opts: [
                include:
                  ~w(accept autocomplete capture cols disabled form list max maxlength min minlength multiple pattern placeholder readonly required rows size step)
              ]
            }
          ],
          slots: [
            %{name: "inner_block", opts: [required: true]}
          ],
          body:
            ~S"""
            %{type: type, field: field} = assigns

            assigns =
              cond do
                match?(%Phoenix.HTML.FormField{}, field) ->
                  assigns
                  |> assign(field: nil, id: assigns.id || field.id)
                  |> assign(:errors, Enum.map(field.errors, & &1))
                  |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
                  |> assign_new(:value, fn -> field.value end)

                type == "checkbox" ->
                  assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", assigns.value) end)

                :else ->
                  assigns
              end
            """
            |> String.trim(),
          template:
            ~S"""
            <%= cond do %>
              <% @type == "checkbox" -> %>
                <div phx-feedback-for={@name}>
                  <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
                    <input type="hidden" name={@name} value="false" />
                    <input type="checkbox" id={@id} name={@name} value="true" checked={@checked} class="rounded border-zinc-300 text-zinc-900 focus:ring-0" {@rest} />
                    <%= @label %>
                  </label>
                  <.error :for={msg <- @errors}><%= msg %></.error>
                </div>

              <% @type == "select" -> %>
                <div phx-feedback-for={@name}>
                  <.label for={@id}><%= @label %></.label>
                  <select
                    id={@id}
                    name={@name}
                    class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
                    multiple={@multiple}
                    {@rest}
                  >
                    <option :if={@prompt} value=""><%= @prompt %></option>
                    <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
                  </select>
                  <.error :for={msg <- @errors}><%= msg %></.error>
                </div>

              <% @type == "textarea" -> %>
                <div phx-feedback-for={@name}>
                  <.label for={@id}><%= @label %></.label>
                  <textarea
                    id={@id}
                    name={@name}
                    class={[
                      "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
                      "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
                      @errors == [] && "border-zinc-300 focus:border-zinc-400",
                      @errors != [] && "border-rose-400 focus:border-rose-400"
                    ]}
                    {@rest}
                  ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
                  <.error :for={msg <- @errors}><%= msg %></.error>
                </div>

              <% :else -> %>
                <div phx-feedback-for={@name}>
                  <.label for={@id}><%= @label %></.label>
                  <input
                    type={@type}
                    name={@name}
                    id={@id}
                    value={Phoenix.HTML.Form.normalize_value(@type, @value)}
                    class={[
                      "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
                      "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
                      @errors == [] && "border-zinc-300 focus:border-zinc-400",
                      @errors != [] && "border-rose-400 focus:border-rose-400"
                    ]}
                    {@rest}
                  />
                  <.error :for={msg <- @errors}><%= msg %></.error>
                </div>
            <% end %>
            """
            |> String.trim(),
          example: ~S|<.input field={@form[:email]} type="email" />|
        },
        %{
          name: "label",
          description: "Render a label",
          thumbnail: "https://placehold.co/400x75?text=label",
          attrs: [
            %{name: "for", type: "string", opts: [default: nil]}
          ],
          slots: [
            %{name: "inner_block", opts: [required: true]}
          ],
          template:
            ~S"""
            <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
              <%= render_slot(@inner_block) %>
            </label>
            """
            |> String.trim(),
          example:
            ~S"""
            <.label for={"newsletter_email"}>
              Email
            </.label>
            """
            |> String.trim(),
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
          template: ~S|<img src={beacon_media_url(@name)} class={@class} {@rest} />|,
          example: ~S|<.image site={@beacon.site} name="beacon.webp" alt="logo" />|,
          category: :media
        },
        %{
          name: "embedded",
          description: "Renders embedded content like an YouTube video or Instagram photo",
          thumbnail: "https://placehold.co/400x75?text=embedded",
          attrs: [
            %{name: "url", type: "string", opts: [required: true]},
            %{name: "class", type: "string", opts: [default: "aspect-auto"]}
          ],
          template: ~S|<ReqEmbed.embed url={@url} class={@class} />|,
          example: ~S|<.embedded url="https://www.youtube.com/watch?v=agkXUp0hCW8" class="w-full aspect-video" />|,
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
          body:
            ~S"""
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
            """
            |> String.trim(),
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
            %{name: "inner_block", opts: []}
          ],
          body:
            ~S"""
            assigns =
              if Enum.empty?(assigns.pages),
                do: Map.put(assigns, :pages, Beacon.Content.list_published_pages(assigns.site, per_page: 3)),
                else: assigns
            """
            |> String.trim(),
          template:
            ~S"""
            <div class="max-w-7xl mx-auto">
              <div class="md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-6 lg:gap-11 md:space-y-0 space-y-10">
                <%= if Enum.empty?(@inner_block) do %>
                  <div :for={page <- @pages}>
                    <article class="hover:ring-2 hover:ring-gray-200 hover:ring-offset-8 flex relative flex-col rounded-lg xl:hover:ring-offset-[12px] 2xl:hover:ring-offset-[16px] active:ring-gray-200 active:ring-offset-8 xl:active:ring-offset-[12px] 2xl:active:ring-offset-[16px] focus-within:ring-2 focus-within:ring-blue-200 focus-within:ring-offset-8 xl:focus-within:ring-offset-[12px] hover:bg-white active:bg-white transition-all duration-300">
                      <div class="flex flex-col">
                        <div>
                          <p class="font-bold text-gray-700"></p>
                          <p class="text-eyebrow font-medium text-gray-500 text-sm text-left">
                            <%= Calendar.strftime(page.updated_at, "%d %B %Y") %>
                          </p>
                        </div>

                        <div class="-order-1 flex gap-x-2 items-center mb-3">
                          <h3 class="font-heading lg:text-xl lg:leading-8 text-lg font-bold leading-7">
                            <.page_link
                              path={page.path}
                              class="after:absolute after:inset-0 after:cursor-pointer focus:outline-none">
                              <%= page.title %>
                            </.page_link>
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
            """
            |> String.trim(),
          example:
            ~S"""
            <.featured_pages :let={page} pages={Beacon.Content.list_published_pages(@beacon.site, per_page: 3)}>
              <article >
                <%= page.title %>
              </article>
            </.featured_pages>
            """
            |> String.trim()
        },
        %{
          name: "flowbite_cta",
          description: "Renders a simple heading, paragraph, and a couple of CTA buttons to encourage users to take action.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_cta",
          template: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
                <div class="max-w-screen-md">
                    <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">
                      Let's find more that brings us together.</h2>
                    <p class="mb-8 font-light text-gray-500 sm:text-xl dark:text-gray-400">
                      Flowbite helps you connect with friends, family and communities of people who share your interests. Connecting with your friends and family as well as discovering new ones is easy with features like Groups, Watch and Marketplace.
                    </p>
                    <div class="flex flex-col space-y-4 sm:flex-row sm:space-y-0 sm:space-x-4">
                      <.page_link path={"/"} class="inline-flex items-center justify-center px-4 py-2.5 text-base font-medium text-center text-white bg-neutral-700 rounded-lg hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
                        Get started
                      </.page_link>
                      <.page_link path={"/"} class="inline-flex items-center justify-center px-4 py-2.5 text-base font-medium text-center text-gray-900 border border-gray-300 rounded-lg hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:focus:ring-gray-600">
                        <svg class="mr-2 -ml-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"></path></svg>
                        View more
                      </.page_link>
                    </div>
                </div>
            </div>
          </section>
          """,
          example: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
                <div class="max-w-screen-md">
                    <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">
                      Let's find more that brings us together.</h2>
                    <p class="mb-8 font-light text-gray-500 sm:text-xl dark:text-gray-400">
                      Flowbite helps you connect with friends, family and communities of people who share your interests. Connecting with your friends and family as well as discovering new ones is easy with features like Groups, Watch and Marketplace.
                    </p>
                    <div class="flex flex-col space-y-4 sm:flex-row sm:space-y-0 sm:space-x-4">
                      <.page_link path={"/"} class="inline-flex items-center justify-center px-4 py-2.5 text-base font-medium text-center text-white bg-neutral-700 rounded-lg hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
                        Get started
                      </.page_link>
                      <.page_link path={"/"} class="inline-flex items-center justify-center px-4 py-2.5 text-base font-medium text-center text-gray-900 border border-gray-300 rounded-lg hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:focus:ring-gray-600">
                        <svg class="mr-2 -ml-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"></path></svg>
                        View more
                      </.page_link>
                    </div>
                </div>
            </div>
          </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_cta_with_image",
          description: "Renders an image or app screenshot next to the CTA button to provide additional visual impact.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_cta_with_image",
          template: """
          <section class="bg-white dark:bg-gray-900">
            <div class="gap-8 items-center py-8 px-4 mx-auto max-w-screen-xl xl:gap-16 md:grid md:grid-cols-2 sm:py-16 lg:px-6">
              <img class="w-full dark:hidden" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/cta/cta-dashboard-mockup.svg" alt="dashboard image">
              <img class="w-full hidden dark:block" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/cta/cta-dashboard-mockup-dark.svg" alt="dashboard image">
              <div class="mt-4 md:mt-0">
                <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">
                  Let's create more tools and ideas that brings us together.
                </h2>
                <p class="mb-6 font-light text-gray-500 md:text-lg dark:text-gray-400">
                 Flowbite helps you connect with friends and communities of people who share your interests. Connecting with your friends and family as well as discovering new ones is easy with features like Groups.
                </p>
                <.page_link path={"/"} class="inline-flex items-center text-white bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-neutral-900">
                  Get started
                  <svg class="ml-2 -mr-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                    <path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                  </svg>
                </.page_link>
              </div>
            </div>
          </section>
          """,
          example: """
          <section class="bg-white dark:bg-gray-900">
            <div class="gap-8 items-center py-8 px-4 mx-auto max-w-screen-xl xl:gap-16 md:grid md:grid-cols-2 sm:py-16 lg:px-6">
              <img class="w-full dark:hidden" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/cta/cta-dashboard-mockup.svg" alt="dashboard image">
              <img class="w-full hidden dark:block" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/cta/cta-dashboard-mockup-dark.svg" alt="dashboard image">
              <div class="mt-4 md:mt-0">
                <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">
                  Let's create more tools and ideas that brings us together.
                </h2>
                <p class="mb-6 font-light text-gray-500 md:text-lg dark:text-gray-400">
                 Flowbite helps you connect with friends and communities of people who share your interests. Connecting with your friends and family as well as discovering new ones is easy with features like Groups.
                </p>
                <.page_link path={"/"} class="inline-flex items-center text-white bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-neutral-900">
                  Get started
                  <svg class="ml-2 -mr-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                    <path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                  </svg>
                </.page_link>
              </div>
            </div>
          </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_cta_centered",
          description: "Renders CTA section with a heading, short paragraph, and a button to encourage users to start a free trial.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_cta_centered",
          template: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
              <div class="mx-auto max-w-screen-sm text-center">
                <h2 class="mb-4 text-4xl tracking-tight font-extrabold leading-tight text-gray-900 dark:text-white">
                  Start your free trial today
                </h2>
                <p class="mb-6 font-light text-gray-500 dark:text-gray-400 md:text-lg">
                  Try Flowbite Platform for 30 days. No credit card required.
                </p>
                <.page_link path={"/"} class="text-white bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 font-medium rounded-lg text-sm px-5 py-2.5 mr-2 mb-2 dark:bg-neutral-600 dark:hover:bg-neutral-700 focus:outline-none dark:focus:ring-neutral-800">
                  Free trial for 30 days
                </.page_link>
              </div>
            </div>
          </section>
          """,
          example: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
              <div class="mx-auto max-w-screen-sm text-center">
                <h2 class="mb-4 text-4xl tracking-tight font-extrabold leading-tight text-gray-900 dark:text-white">
                  Start your free trial today
                </h2>
                <p class="mb-6 font-light text-gray-500 dark:text-gray-400 md:text-lg">
                  Try Flowbite Platform for 30 days. No credit card required.
                </p>
                <.page_link path={"/"} class="text-white bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 font-medium rounded-lg text-sm px-5 py-2.5 mr-2 mb-2 dark:bg-neutral-600 dark:hover:bg-neutral-700 focus:outline-none dark:focus:ring-neutral-800">
                  Free trial for 30 days
                </.page_link>
              </div>
            </div>
          </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_hero",
          description: "Renders an announcement badge, heading, CTA buttons, and customer logos to showcase what your website offers.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_hero",
          template: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl text-center lg:py-16 lg:px-12">
              <.page_link path={"/"} class="inline-flex justify-between items-center py-1 px-1 pr-4 mb-7 text-sm text-gray-700 bg-gray-100 rounded-full dark:bg-gray-800 dark:text-white hover:bg-gray-200 dark:hover:bg-gray-700" role="alert">
                <span class="text-xs bg-neutral-600 rounded-full text-white px-4 py-1.5 mr-3">New</span>
                <span class="text-sm font-medium">Flowbite is out! See what's new</span>
                <svg class="ml-2 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path></svg>
              </.page_link>
              <h1 class="mb-4 text-4xl font-extrabold tracking-tight leading-none text-gray-900 md:text-5xl lg:text-6xl dark:text-white">
                We invest in the world’s potential
              </h1>
              <p class="mb-8 text-lg font-normal text-gray-500 lg:text-xl sm:px-16 xl:px-48 dark:text-gray-400">
                Here at Flowbite we focus on markets where technology, innovation, and capital can unlock long-term value and drive economic growth.
              </p>
              <div class="flex flex-col mb-8 lg:mb-16 space-y-4 sm:flex-row sm:justify-center sm:space-y-0 sm:space-x-4">
                <.page_link path={"/"} class="inline-flex justify-center items-center py-3 px-5 text-base font-medium text-center text-white rounded-lg bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
                  Learn more
                  <svg class="ml-2 -mr-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path></svg>
                </.page_link>
                <.page_link path={"/"} class="inline-flex justify-center items-center py-3 px-5 text-base font-medium text-center text-gray-900 rounded-lg border border-gray-300 hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-700 dark:hover:bg-gray-700 dark:focus:ring-gray-800">
                  <svg class="mr-2 -ml-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"></path></svg>
                  Watch video
                </.page_link>
              </div>
              <div class="px-4 mx-auto text-center md:max-w-screen-md lg:max-w-screen-lg lg:px-36">
                <span class="font-semibold text-gray-400 uppercase">FEATURED IN</span>
                <div class="flex flex-wrap justify-center items-center mt-8 text-gray-500 sm:justify-between">
                  <.page_link path={"/"} class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
                    <svg class="h-8" viewBox="0 0 132 29" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M39.4555 5.17846C38.9976 3.47767 37.6566 2.13667 35.9558 1.67876C32.8486 0.828369 20.4198 0.828369 20.4198 0.828369C20.4198 0.828369 7.99099 0.828369 4.88379 1.64606C3.21571 2.10396 1.842 3.47767 1.38409 5.17846C0.566406 8.28567 0.566406 14.729 0.566406 14.729C0.566406 14.729 0.566406 21.2051 1.38409 24.2796C1.842 25.9804 3.183 27.3214 4.88379 27.7793C8.0237 28.6297 20.4198 28.6297 20.4198 28.6297C20.4198 28.6297 32.8486 28.6297 35.9558 27.812C37.6566 27.3541 38.9976 26.0131 39.4555 24.3123C40.2732 21.2051 40.2732 14.7618 40.2732 14.7618C40.2732 14.7618 40.3059 8.28567 39.4555 5.17846Z" fill="currentColor"/>
                      <path d="M16.4609 8.77612V20.6816L26.7966 14.7289L16.4609 8.77612Z" fill="white"/>
                      <path d="M64.272 25.0647C63.487 24.5413 62.931 23.7237 62.6039 22.5789C62.2768 21.4669 62.1133 19.9623 62.1133 18.1307V15.6122C62.1133 13.7479 62.3095 12.2434 62.6693 11.0986C63.0618 9.95386 63.6505 9.13618 64.4355 8.61286C65.2532 8.08954 66.2998 7.82788 67.6081 7.82788C68.8837 7.82788 69.9304 8.08954 70.7153 8.61286C71.5003 9.13618 72.0564 9.98657 72.4161 11.0986C72.7759 12.2107 72.9722 13.7152 72.9722 15.6122V18.1307C72.9722 19.995 72.8086 21.4669 72.4488 22.6116C72.0891 23.7237 71.533 24.5741 70.7481 25.0974C69.9631 25.6207 68.8837 25.8824 67.5427 25.8824C66.169 25.8496 65.057 25.588 64.272 25.0647ZM68.6875 22.3172C68.9164 21.7612 69.0146 20.8127 69.0146 19.5371V14.1077C69.0146 12.8648 68.9164 11.949 68.6875 11.3603C68.4585 10.7715 68.0988 10.5099 67.5427 10.5099C67.0194 10.5099 66.6269 10.8043 66.4307 11.3603C66.2017 11.949 66.1036 12.8648 66.1036 14.1077V19.5371C66.1036 20.8127 66.2017 21.7612 66.4307 22.3172C66.6269 22.8733 67.0194 23.1676 67.5754 23.1676C68.0987 23.1676 68.4585 22.906 68.6875 22.3172Z" fill="currentColor"/>
                      <path d="M124.649 18.1634V19.0465C124.649 20.1586 124.682 21.009 124.748 21.565C124.813 22.121 124.944 22.5462 125.173 22.7752C125.369 23.0368 125.696 23.1677 126.154 23.1677C126.743 23.1677 127.135 22.9387 127.364 22.4808C127.593 22.0229 127.691 21.2706 127.724 20.1913L131.093 20.3875C131.125 20.5511 131.125 20.7473 131.125 21.009C131.125 22.6117 130.7 23.8218 129.817 24.6068C128.934 25.3918 127.691 25.7843 126.089 25.7843C124.159 25.7843 122.818 25.1628 122.033 23.9527C121.248 22.7425 120.855 20.8782 120.855 18.327V15.2852C120.855 12.6686 121.248 10.7715 122.066 9.56136C122.883 8.35119 124.257 7.76245 126.187 7.76245C127.528 7.76245 128.574 8.02411 129.294 8.51472C130.013 9.00534 130.504 9.79032 130.798 10.8042C131.093 11.8509 131.223 13.29 131.223 15.1216V18.098H124.649V18.1634ZM125.14 10.837C124.944 11.0986 124.813 11.4911 124.748 12.0471C124.682 12.6032 124.649 13.4536 124.649 14.5983V15.8412H127.528V14.5983C127.528 13.4863 127.495 12.6359 127.43 12.0471C127.364 11.4584 127.201 11.0659 127.004 10.837C126.808 10.608 126.481 10.4772 126.089 10.4772C125.631 10.4445 125.336 10.5753 125.14 10.837Z" fill="currentColor"/>
                      <path d="M54.7216 17.8362L50.2734 1.71143H54.1656L55.7356 9.0052C56.1281 10.8041 56.4224 12.3414 56.6187 13.617H56.7168C56.8476 12.7011 57.142 11.1966 57.5999 9.0379L59.2353 1.71143H63.1274L58.6138 17.8362V25.5552H54.7543V17.8362H54.7216Z" fill="currentColor"/>
                      <path d="M85.6299 8.15479V25.5878H82.5554L82.2283 23.4619H82.1302C81.3125 25.0645 80.0369 25.8822 78.3688 25.8822C77.2241 25.8822 76.3737 25.4897 75.8177 24.7375C75.2617 23.9852 75 22.8077 75 21.1723V8.15479H78.9249V20.9434C78.9249 21.7284 79.023 22.2844 79.1865 22.6115C79.3501 22.9385 79.6444 23.1021 80.0369 23.1021C80.364 23.1021 80.6911 23.004 81.0181 22.775C81.3452 22.5788 81.5742 22.3171 81.705 21.99V8.15479H85.6299Z" fill="currentColor"/>
                      <path d="M105.747 8.15479V25.5878H102.673L102.346 23.4619H102.247C101.43 25.0645 100.154 25.8822 98.4861 25.8822C97.3413 25.8822 96.4909 25.4897 95.9349 24.7375C95.3788 23.9852 95.1172 22.8077 95.1172 21.1723V8.15479H99.0421V20.9434C99.0421 21.7284 99.1402 22.2844 99.3038 22.6115C99.4673 22.9385 99.7617 23.1021 100.154 23.1021C100.481 23.1021 100.808 23.004 101.135 22.775C101.462 22.5788 101.691 22.3171 101.822 21.99V8.15479H105.747Z" fill="currentColor"/>
                      <path d="M96.2907 4.88405H92.3986V25.5552H88.5718V4.88405H84.6797V1.71143H96.2907V4.88405Z" fill="currentColor"/>
                      <path d="M118.731 10.935C118.502 9.82293 118.11 9.03795 117.587 8.54734C117.063 8.05672 116.311 7.79506 115.395 7.79506C114.676 7.79506 113.989 7.99131 113.367 8.41651C112.746 8.809 112.255 9.36502 111.928 10.0192H111.896V0.828369H108.102V25.5552H111.34L111.732 23.9199H111.83C112.125 24.5086 112.582 24.9665 113.204 25.3263C113.825 25.6533 114.479 25.8496 115.232 25.8496C116.573 25.8496 117.521 25.2281 118.143 24.018C118.764 22.8078 119.091 20.8781 119.091 18.2942V15.5467C119.059 13.5516 118.96 12.0143 118.731 10.935ZM115.134 18.0325C115.134 19.3081 115.068 20.2893 114.97 21.0089C114.872 21.7285 114.676 22.2518 114.447 22.5461C114.185 22.8405 113.858 23.004 113.466 23.004C113.138 23.004 112.844 22.9386 112.582 22.7751C112.321 22.6116 112.092 22.3826 111.928 22.0882V12.2106C112.059 11.7527 112.288 11.3602 112.615 11.0331C112.942 10.7387 113.302 10.5752 113.662 10.5752C114.054 10.5752 114.381 10.7387 114.578 11.0331C114.807 11.3602 114.937 11.8835 115.036 12.6031C115.134 13.3553 115.166 14.402 115.166 15.743V18.0325H115.134Z" fill="currentColor"/>
                    </svg>
                  </.page_link>
                  <.page_link path={"/"} class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
                    <svg class="h-11" viewBox="0 0 208 42" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M42.7714 20.729C42.7714 31.9343 33.6867 41.019 22.4814 41.019C11.2747 41.019 2.19141 31.9343 2.19141 20.729C2.19141 9.52228 11.2754 0.438965 22.4814 0.438965C33.6867 0.438965 42.7714 9.52297 42.7714 20.729Z" fill="currentColor"/>
                      <path d="M25.1775 21.3312H20.1389V15.9959H25.1775C25.5278 15.9959 25.8747 16.0649 26.1983 16.1989C26.522 16.333 26.8161 16.5295 27.0638 16.7772C27.3115 17.0249 27.508 17.319 27.6421 17.6427C27.7761 17.9663 27.8451 18.3132 27.8451 18.6635C27.8451 19.0139 27.7761 19.3608 27.6421 19.6844C27.508 20.0081 27.3115 20.3021 27.0638 20.5499C26.8161 20.7976 26.522 20.9941 26.1983 21.1281C25.8747 21.2622 25.5278 21.3312 25.1775 21.3312ZM25.1775 12.439H16.582V30.2234H20.1389V24.8881H25.1775C28.6151 24.8881 31.402 22.1012 31.402 18.6635C31.402 15.2258 28.6151 12.439 25.1775 12.439Z" fill="white"/>
                      <path d="M74.9361 17.4611C74.9361 16.1521 73.9305 15.3588 72.6239 15.3588H69.1216V19.5389H72.6248C73.9313 19.5389 74.9369 18.7457 74.9369 17.4611H74.9361ZM65.8047 28.2977V12.439H73.0901C76.4778 12.439 78.3213 14.7283 78.3213 17.4611C78.3213 20.1702 76.4542 22.4588 73.0901 22.4588H69.1216V28.2977H65.8055H65.8047ZM80.3406 28.2977V16.7362H83.3044V18.2543C84.122 17.2731 85.501 16.4563 86.9027 16.4563V19.3518C86.6912 19.3054 86.4349 19.2826 86.0851 19.2826C85.1039 19.2826 83.7949 19.8424 83.3044 20.5681V28.2977H80.3397H80.3406ZM96.8802 22.3652C96.8802 20.6136 95.8503 19.0955 93.9823 19.0955C92.1364 19.0955 91.1105 20.6136 91.1105 22.366C91.1105 24.1404 92.1364 25.6585 93.9823 25.6585C95.8503 25.6585 96.8794 24.1404 96.8794 22.3652H96.8802ZM88.0263 22.3652C88.0263 19.1663 90.2684 16.4563 93.9823 16.4563C97.7198 16.4563 99.962 19.1655 99.962 22.3652C99.962 25.5649 97.7198 28.2977 93.9823 28.2977C90.2684 28.2977 88.0263 25.5649 88.0263 22.3652ZM109.943 24.3739V20.3801C109.452 19.6316 108.378 19.0955 107.396 19.0955C105.693 19.0955 104.524 20.4265 104.524 22.366C104.524 24.3267 105.693 25.6585 107.396 25.6585C108.378 25.6585 109.452 25.1215 109.943 24.3731V24.3739ZM109.943 28.2977V26.5697C109.054 27.6899 107.841 28.2977 106.462 28.2977C103.637 28.2977 101.465 26.1499 101.465 22.3652C101.465 18.6993 103.59 16.4563 106.462 16.4563C107.793 16.4563 109.054 17.0177 109.943 18.1843V12.439H112.932V28.2977H109.943ZM123.497 28.2977V26.5925C122.727 27.4337 121.372 28.2977 119.526 28.2977C117.052 28.2977 115.884 26.9431 115.884 24.7473V16.7362H118.849V23.5798C118.849 25.1451 119.666 25.6585 120.927 25.6585C122.071 25.6585 122.983 25.028 123.497 24.3731V16.7362H126.463V28.2977H123.497ZM128.69 22.3652C128.69 18.9092 131.212 16.4563 134.67 16.4563C136.982 16.4563 138.383 17.4611 139.131 18.4886L137.191 20.3093C136.655 19.5153 135.838 19.0955 134.81 19.0955C133.011 19.0955 131.751 20.4037 131.751 22.366C131.751 24.3267 133.011 25.6585 134.81 25.6585C135.838 25.6585 136.655 25.1915 137.191 24.4203L139.131 26.2426C138.383 27.2702 136.982 28.2977 134.67 28.2977C131.212 28.2977 128.69 25.8456 128.69 22.3652ZM141.681 25.1915V19.329H139.813V16.7362H141.681V13.6528H144.648V16.7362H146.935V19.329H144.648V24.3975C144.648 25.1215 145.02 25.6585 145.675 25.6585C146.118 25.6585 146.541 25.495 146.702 25.3087L147.334 27.5728C146.891 27.9714 146.096 28.2977 144.857 28.2977C142.779 28.2977 141.681 27.2238 141.681 25.1915ZM165.935 28.2977V21.454H158.577V28.2977H155.263V12.439H158.577V18.5577H165.935V12.4398H169.275V28.2977H165.935ZM179.889 28.2977V26.5925C179.119 27.4337 177.764 28.2977 175.919 28.2977C173.443 28.2977 172.276 26.9431 172.276 24.7473V16.7362H175.241V23.5798C175.241 25.1451 176.058 25.6585 177.32 25.6585C178.464 25.6585 179.376 25.028 179.889 24.3731V16.7362H182.856V28.2977H179.889ZM193.417 28.2977V21.1986C193.417 19.6333 192.602 19.0963 191.339 19.0963C190.172 19.0963 189.285 19.7504 188.77 20.4045V28.2985H185.806V16.7362H188.77V18.1843C189.495 17.3439 190.896 16.4563 192.718 16.4563C195.217 16.4563 196.408 17.8573 196.408 20.0523V28.2977H193.418H193.417ZM199.942 25.1915V19.329H198.076V16.7362H199.943V13.6528H202.91V16.7362H205.198V19.329H202.91V24.3975C202.91 25.1215 203.282 25.6585 203.936 25.6585C204.38 25.6585 204.802 25.495 204.965 25.3087L205.595 27.5728C205.152 27.9714 204.356 28.2977 203.119 28.2977C201.04 28.2977 199.943 27.2238 199.943 25.1915" fill="currentColor"/>
                    </svg>
                  </.page_link>
                  <.page_link path={"/"} class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
                    <svg class="h-11" viewBox="0 0 120 41" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M20.058 40.5994C31.0322 40.5994 39.9286 31.7031 39.9286 20.7289C39.9286 9.75473 31.0322 0.858398 20.058 0.858398C9.08385 0.858398 0.1875 9.75473 0.1875 20.7289C0.1875 31.7031 9.08385 40.5994 20.058 40.5994Z" fill="currentColor"/>
                      <path d="M33.3139 20.729C33.3139 19.1166 32.0101 17.8362 30.4211 17.8362C29.6388 17.8362 28.9272 18.1442 28.4056 18.6424C26.414 17.2196 23.687 16.2949 20.6518 16.1765L21.9796 9.96387L26.2951 10.8885C26.3429 11.9793 27.2437 12.8567 28.3584 12.8567C29.4965 12.8567 30.4211 11.9321 30.4211 10.7935C30.4211 9.65536 29.4965 8.73071 28.3584 8.73071C27.5522 8.73071 26.8406 9.20497 26.5086 9.89271L21.6954 8.87303C21.553 8.84917 21.4107 8.87303 21.3157 8.94419C21.1972 9.01535 21.1261 9.13381 21.1026 9.27613L19.6321 16.1999C16.5497 16.2949 13.7753 17.2196 11.7599 18.6662C11.2171 18.1478 10.495 17.8589 9.74439 17.86C8.13201 17.86 6.85156 19.1639 6.85156 20.7529C6.85156 21.9383 7.56272 22.9341 8.55897 23.3849C8.51123 23.6691 8.48781 23.9538 8.48781 24.2623C8.48781 28.7197 13.6807 32.348 20.083 32.348C26.4852 32.348 31.6781 28.7436 31.6781 24.2623C31.6781 23.9776 31.6543 23.6691 31.607 23.3849C32.6028 22.9341 33.3139 21.9144 33.3139 20.729ZM13.4434 22.7918C13.4434 21.6536 14.368 20.729 15.5066 20.729C16.6447 20.729 17.5694 21.6536 17.5694 22.7918C17.5694 23.9299 16.6447 24.855 15.5066 24.855C14.368 24.8784 13.4434 23.9299 13.4434 22.7918ZM24.9913 28.2694C23.5685 29.6921 20.8653 29.7872 20.083 29.7872C19.2768 29.7872 16.5736 29.6683 15.1742 28.2694C14.9612 28.0559 14.9612 27.7239 15.1742 27.5105C15.3877 27.2974 15.7196 27.2974 15.9331 27.5105C16.8343 28.4117 18.7314 28.7197 20.083 28.7197C21.4346 28.7197 23.355 28.4117 24.2324 27.5105C24.4459 27.2974 24.7778 27.2974 24.9913 27.5105C25.1809 27.7239 25.1809 28.0559 24.9913 28.2694ZM24.6116 24.8784C23.4735 24.8784 22.5488 23.9538 22.5488 22.8156C22.5488 21.6775 23.4735 20.7529 24.6116 20.7529C25.7502 20.7529 26.6748 21.6775 26.6748 22.8156C26.6748 23.9299 25.7502 24.8784 24.6116 24.8784Z" fill="white"/>
                      <path d="M108.412 16.6268C109.8 16.6268 110.926 15.5014 110.926 14.1132C110.926 12.725 109.8 11.5996 108.412 11.5996C107.024 11.5996 105.898 12.725 105.898 14.1132C105.898 15.5014 107.024 16.6268 108.412 16.6268Z" fill="currentColor"/>
                      <path d="M72.5114 24.8309C73.7446 24.8309 74.4557 23.9063 74.4084 23.0051C74.385 22.5308 74.3373 22.2223 74.29 21.9854C73.5311 18.7133 70.8756 16.2943 67.7216 16.2943C63.9753 16.2943 60.9401 19.6853 60.9401 23.8586C60.9401 28.0318 63.9753 31.4228 67.7216 31.4228C70.0694 31.4228 71.753 30.5693 72.9622 29.2177C73.5549 28.5538 73.4365 27.5341 72.7249 27.036C72.1322 26.6329 71.3972 26.7752 70.8517 27.2256C70.3302 27.6765 69.3344 28.5772 67.7216 28.5772C65.825 28.5772 64.2126 26.941 63.8568 24.7832H72.5114V24.8309ZM67.6981 19.1637C69.4051 19.1637 70.8756 20.4915 71.421 22.3173H63.9752C64.5207 20.468 65.9907 19.1637 67.6981 19.1637ZM61.0824 17.7883C61.0824 17.0771 60.5609 16.5078 59.897 16.3894C57.8338 16.0813 55.8895 16.8397 54.7752 18.2391V18.049C54.7752 17.1717 54.0636 16.6267 53.3525 16.6267C52.5697 16.6267 51.9297 17.2667 51.9297 18.049V29.6681C51.9297 30.427 52.4985 31.0908 53.2574 31.1381C54.0875 31.1854 54.7752 30.5454 54.7752 29.7154V23.7162C54.7752 21.0608 56.7668 18.8791 59.5173 19.1876H59.802C60.5131 19.1399 61.0824 18.5233 61.0824 17.7883ZM109.834 19.306C109.834 18.5233 109.194 17.8833 108.412 17.8833C107.629 17.8833 106.989 18.5233 106.989 19.306V29.7154C106.989 30.4981 107.629 31.1381 108.412 31.1381C109.194 31.1381 109.834 30.4981 109.834 29.7154V19.306ZM88.6829 11.4338C88.6829 10.651 88.0429 10.011 87.2602 10.011C86.4779 10.011 85.8379 10.651 85.8379 11.4338V17.7648C84.8655 16.7924 83.6562 16.3182 82.2096 16.3182C78.4632 16.3182 75.4281 19.7091 75.4281 23.8824C75.4281 28.0557 78.4632 31.4466 82.2096 31.4466C83.6562 31.4466 84.8893 30.9485 85.8613 29.9761C85.9797 30.6405 86.5729 31.1381 87.2602 31.1381C88.0429 31.1381 88.6829 30.4981 88.6829 29.7154V11.4338ZM82.2334 28.6245C80.0518 28.6245 78.2971 26.5145 78.2971 23.8824C78.2971 21.2742 80.0518 19.1399 82.2334 19.1399C84.4151 19.1399 86.1698 21.2504 86.1698 23.8824C86.1698 26.5145 84.3912 28.6245 82.2334 28.6245ZM103.527 11.4338C103.527 10.651 102.887 10.011 102.104 10.011C101.322 10.011 100.681 10.651 100.681 11.4338V17.7648C99.7093 16.7924 98.5 16.3182 97.0534 16.3182C93.307 16.3182 90.2719 19.7091 90.2719 23.8824C90.2719 28.0557 93.307 31.4466 97.0534 31.4466C98.5 31.4466 99.7327 30.9485 100.705 29.9761C100.824 30.6405 101.416 31.1381 102.104 31.1381C102.887 31.1381 103.527 30.4981 103.527 29.7154V11.4338ZM97.0534 28.6245C94.8717 28.6245 93.1174 26.5145 93.1174 23.8824C93.1174 21.2742 94.8717 19.1399 97.0534 19.1399C99.235 19.1399 100.99 21.2504 100.99 23.8824C100.99 26.5145 99.235 28.6245 97.0534 28.6245ZM117.042 29.7392V19.1637H118.299C118.963 19.1637 119.556 18.6656 119.603 17.9779C119.651 17.2428 119.058 16.6267 118.347 16.6267H117.042V14.6347C117.042 13.8758 116.474 13.2119 115.715 13.1646C114.885 13.1173 114.197 13.7573 114.197 14.5874V16.6501H113.011C112.348 16.6501 111.755 17.1483 111.708 17.836C111.66 18.571 112.253 19.1876 112.964 19.1876H114.173V29.7631C114.173 30.5454 114.814 31.1854 115.596 31.1854C116.426 31.1381 117.042 30.5216 117.042 29.7392Z" fill="currentColor"/>
                    </svg>
                  </.page_link>
                </div>
              </div>
            </div>
          </section>
          """,
          example: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl text-center lg:py-16 lg:px-12">
              <.page_link path={"/"} class="inline-flex justify-between items-center py-1 px-1 pr-4 mb-7 text-sm text-gray-700 bg-gray-100 rounded-full dark:bg-gray-800 dark:text-white hover:bg-gray-200 dark:hover:bg-gray-700" role="alert">
                <span class="text-xs bg-neutral-600 rounded-full text-white px-4 py-1.5 mr-3">New</span>
                <span class="text-sm font-medium">Flowbite is out! See what's new</span>
                <svg class="ml-2 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path></svg>
              </.page_link>
              <h1 class="mb-4 text-4xl font-extrabold tracking-tight leading-none text-gray-900 md:text-5xl lg:text-6xl dark:text-white">
                We invest in the world’s potential
              </h1>
              <p class="mb-8 text-lg font-normal text-gray-500 lg:text-xl sm:px-16 xl:px-48 dark:text-gray-400">
                Here at Flowbite we focus on markets where technology, innovation, and capital can unlock long-term value and drive economic growth.
              </p>
              <div class="flex flex-col mb-8 lg:mb-16 space-y-4 sm:flex-row sm:justify-center sm:space-y-0 sm:space-x-4">
                <.page_link path={"/"} class="inline-flex justify-center items-center py-3 px-5 text-base font-medium text-center text-white rounded-lg bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
                  Learn more
                  <svg class="ml-2 -mr-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path></svg>
                </.page_link>
                <.page_link path={"/"} class="inline-flex justify-center items-center py-3 px-5 text-base font-medium text-center text-gray-900 rounded-lg border border-gray-300 hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-700 dark:hover:bg-gray-700 dark:focus:ring-gray-800">
                  <svg class="mr-2 -ml-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"></path></svg>
                  Watch video
                </.page_link>
              </div>
              <div class="px-4 mx-auto text-center md:max-w-screen-md lg:max-w-screen-lg lg:px-36">
                <span class="font-semibold text-gray-400 uppercase">FEATURED IN</span>
                <div class="flex flex-wrap justify-center items-center mt-8 text-gray-500 sm:justify-between">
                  <.page_link path={"/"} class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
                    <svg class="h-8" viewBox="0 0 132 29" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M39.4555 5.17846C38.9976 3.47767 37.6566 2.13667 35.9558 1.67876C32.8486 0.828369 20.4198 0.828369 20.4198 0.828369C20.4198 0.828369 7.99099 0.828369 4.88379 1.64606C3.21571 2.10396 1.842 3.47767 1.38409 5.17846C0.566406 8.28567 0.566406 14.729 0.566406 14.729C0.566406 14.729 0.566406 21.2051 1.38409 24.2796C1.842 25.9804 3.183 27.3214 4.88379 27.7793C8.0237 28.6297 20.4198 28.6297 20.4198 28.6297C20.4198 28.6297 32.8486 28.6297 35.9558 27.812C37.6566 27.3541 38.9976 26.0131 39.4555 24.3123C40.2732 21.2051 40.2732 14.7618 40.2732 14.7618C40.2732 14.7618 40.3059 8.28567 39.4555 5.17846Z" fill="currentColor"/>
                      <path d="M16.4609 8.77612V20.6816L26.7966 14.7289L16.4609 8.77612Z" fill="white"/>
                      <path d="M64.272 25.0647C63.487 24.5413 62.931 23.7237 62.6039 22.5789C62.2768 21.4669 62.1133 19.9623 62.1133 18.1307V15.6122C62.1133 13.7479 62.3095 12.2434 62.6693 11.0986C63.0618 9.95386 63.6505 9.13618 64.4355 8.61286C65.2532 8.08954 66.2998 7.82788 67.6081 7.82788C68.8837 7.82788 69.9304 8.08954 70.7153 8.61286C71.5003 9.13618 72.0564 9.98657 72.4161 11.0986C72.7759 12.2107 72.9722 13.7152 72.9722 15.6122V18.1307C72.9722 19.995 72.8086 21.4669 72.4488 22.6116C72.0891 23.7237 71.533 24.5741 70.7481 25.0974C69.9631 25.6207 68.8837 25.8824 67.5427 25.8824C66.169 25.8496 65.057 25.588 64.272 25.0647ZM68.6875 22.3172C68.9164 21.7612 69.0146 20.8127 69.0146 19.5371V14.1077C69.0146 12.8648 68.9164 11.949 68.6875 11.3603C68.4585 10.7715 68.0988 10.5099 67.5427 10.5099C67.0194 10.5099 66.6269 10.8043 66.4307 11.3603C66.2017 11.949 66.1036 12.8648 66.1036 14.1077V19.5371C66.1036 20.8127 66.2017 21.7612 66.4307 22.3172C66.6269 22.8733 67.0194 23.1676 67.5754 23.1676C68.0987 23.1676 68.4585 22.906 68.6875 22.3172Z" fill="currentColor"/>
                      <path d="M124.649 18.1634V19.0465C124.649 20.1586 124.682 21.009 124.748 21.565C124.813 22.121 124.944 22.5462 125.173 22.7752C125.369 23.0368 125.696 23.1677 126.154 23.1677C126.743 23.1677 127.135 22.9387 127.364 22.4808C127.593 22.0229 127.691 21.2706 127.724 20.1913L131.093 20.3875C131.125 20.5511 131.125 20.7473 131.125 21.009C131.125 22.6117 130.7 23.8218 129.817 24.6068C128.934 25.3918 127.691 25.7843 126.089 25.7843C124.159 25.7843 122.818 25.1628 122.033 23.9527C121.248 22.7425 120.855 20.8782 120.855 18.327V15.2852C120.855 12.6686 121.248 10.7715 122.066 9.56136C122.883 8.35119 124.257 7.76245 126.187 7.76245C127.528 7.76245 128.574 8.02411 129.294 8.51472C130.013 9.00534 130.504 9.79032 130.798 10.8042C131.093 11.8509 131.223 13.29 131.223 15.1216V18.098H124.649V18.1634ZM125.14 10.837C124.944 11.0986 124.813 11.4911 124.748 12.0471C124.682 12.6032 124.649 13.4536 124.649 14.5983V15.8412H127.528V14.5983C127.528 13.4863 127.495 12.6359 127.43 12.0471C127.364 11.4584 127.201 11.0659 127.004 10.837C126.808 10.608 126.481 10.4772 126.089 10.4772C125.631 10.4445 125.336 10.5753 125.14 10.837Z" fill="currentColor"/>
                      <path d="M54.7216 17.8362L50.2734 1.71143H54.1656L55.7356 9.0052C56.1281 10.8041 56.4224 12.3414 56.6187 13.617H56.7168C56.8476 12.7011 57.142 11.1966 57.5999 9.0379L59.2353 1.71143H63.1274L58.6138 17.8362V25.5552H54.7543V17.8362H54.7216Z" fill="currentColor"/>
                      <path d="M85.6299 8.15479V25.5878H82.5554L82.2283 23.4619H82.1302C81.3125 25.0645 80.0369 25.8822 78.3688 25.8822C77.2241 25.8822 76.3737 25.4897 75.8177 24.7375C75.2617 23.9852 75 22.8077 75 21.1723V8.15479H78.9249V20.9434C78.9249 21.7284 79.023 22.2844 79.1865 22.6115C79.3501 22.9385 79.6444 23.1021 80.0369 23.1021C80.364 23.1021 80.6911 23.004 81.0181 22.775C81.3452 22.5788 81.5742 22.3171 81.705 21.99V8.15479H85.6299Z" fill="currentColor"/>
                      <path d="M105.747 8.15479V25.5878H102.673L102.346 23.4619H102.247C101.43 25.0645 100.154 25.8822 98.4861 25.8822C97.3413 25.8822 96.4909 25.4897 95.9349 24.7375C95.3788 23.9852 95.1172 22.8077 95.1172 21.1723V8.15479H99.0421V20.9434C99.0421 21.7284 99.1402 22.2844 99.3038 22.6115C99.4673 22.9385 99.7617 23.1021 100.154 23.1021C100.481 23.1021 100.808 23.004 101.135 22.775C101.462 22.5788 101.691 22.3171 101.822 21.99V8.15479H105.747Z" fill="currentColor"/>
                      <path d="M96.2907 4.88405H92.3986V25.5552H88.5718V4.88405H84.6797V1.71143H96.2907V4.88405Z" fill="currentColor"/>
                      <path d="M118.731 10.935C118.502 9.82293 118.11 9.03795 117.587 8.54734C117.063 8.05672 116.311 7.79506 115.395 7.79506C114.676 7.79506 113.989 7.99131 113.367 8.41651C112.746 8.809 112.255 9.36502 111.928 10.0192H111.896V0.828369H108.102V25.5552H111.34L111.732 23.9199H111.83C112.125 24.5086 112.582 24.9665 113.204 25.3263C113.825 25.6533 114.479 25.8496 115.232 25.8496C116.573 25.8496 117.521 25.2281 118.143 24.018C118.764 22.8078 119.091 20.8781 119.091 18.2942V15.5467C119.059 13.5516 118.96 12.0143 118.731 10.935ZM115.134 18.0325C115.134 19.3081 115.068 20.2893 114.97 21.0089C114.872 21.7285 114.676 22.2518 114.447 22.5461C114.185 22.8405 113.858 23.004 113.466 23.004C113.138 23.004 112.844 22.9386 112.582 22.7751C112.321 22.6116 112.092 22.3826 111.928 22.0882V12.2106C112.059 11.7527 112.288 11.3602 112.615 11.0331C112.942 10.7387 113.302 10.5752 113.662 10.5752C114.054 10.5752 114.381 10.7387 114.578 11.0331C114.807 11.3602 114.937 11.8835 115.036 12.6031C115.134 13.3553 115.166 14.402 115.166 15.743V18.0325H115.134Z" fill="currentColor"/>
                    </svg>
                  </.page_link>
                  <.page_link path={"/"} class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
                    <svg class="h-11" viewBox="0 0 208 42" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M42.7714 20.729C42.7714 31.9343 33.6867 41.019 22.4814 41.019C11.2747 41.019 2.19141 31.9343 2.19141 20.729C2.19141 9.52228 11.2754 0.438965 22.4814 0.438965C33.6867 0.438965 42.7714 9.52297 42.7714 20.729Z" fill="currentColor"/>
                      <path d="M25.1775 21.3312H20.1389V15.9959H25.1775C25.5278 15.9959 25.8747 16.0649 26.1983 16.1989C26.522 16.333 26.8161 16.5295 27.0638 16.7772C27.3115 17.0249 27.508 17.319 27.6421 17.6427C27.7761 17.9663 27.8451 18.3132 27.8451 18.6635C27.8451 19.0139 27.7761 19.3608 27.6421 19.6844C27.508 20.0081 27.3115 20.3021 27.0638 20.5499C26.8161 20.7976 26.522 20.9941 26.1983 21.1281C25.8747 21.2622 25.5278 21.3312 25.1775 21.3312ZM25.1775 12.439H16.582V30.2234H20.1389V24.8881H25.1775C28.6151 24.8881 31.402 22.1012 31.402 18.6635C31.402 15.2258 28.6151 12.439 25.1775 12.439Z" fill="white"/>
                      <path d="M74.9361 17.4611C74.9361 16.1521 73.9305 15.3588 72.6239 15.3588H69.1216V19.5389H72.6248C73.9313 19.5389 74.9369 18.7457 74.9369 17.4611H74.9361ZM65.8047 28.2977V12.439H73.0901C76.4778 12.439 78.3213 14.7283 78.3213 17.4611C78.3213 20.1702 76.4542 22.4588 73.0901 22.4588H69.1216V28.2977H65.8055H65.8047ZM80.3406 28.2977V16.7362H83.3044V18.2543C84.122 17.2731 85.501 16.4563 86.9027 16.4563V19.3518C86.6912 19.3054 86.4349 19.2826 86.0851 19.2826C85.1039 19.2826 83.7949 19.8424 83.3044 20.5681V28.2977H80.3397H80.3406ZM96.8802 22.3652C96.8802 20.6136 95.8503 19.0955 93.9823 19.0955C92.1364 19.0955 91.1105 20.6136 91.1105 22.366C91.1105 24.1404 92.1364 25.6585 93.9823 25.6585C95.8503 25.6585 96.8794 24.1404 96.8794 22.3652H96.8802ZM88.0263 22.3652C88.0263 19.1663 90.2684 16.4563 93.9823 16.4563C97.7198 16.4563 99.962 19.1655 99.962 22.3652C99.962 25.5649 97.7198 28.2977 93.9823 28.2977C90.2684 28.2977 88.0263 25.5649 88.0263 22.3652ZM109.943 24.3739V20.3801C109.452 19.6316 108.378 19.0955 107.396 19.0955C105.693 19.0955 104.524 20.4265 104.524 22.366C104.524 24.3267 105.693 25.6585 107.396 25.6585C108.378 25.6585 109.452 25.1215 109.943 24.3731V24.3739ZM109.943 28.2977V26.5697C109.054 27.6899 107.841 28.2977 106.462 28.2977C103.637 28.2977 101.465 26.1499 101.465 22.3652C101.465 18.6993 103.59 16.4563 106.462 16.4563C107.793 16.4563 109.054 17.0177 109.943 18.1843V12.439H112.932V28.2977H109.943ZM123.497 28.2977V26.5925C122.727 27.4337 121.372 28.2977 119.526 28.2977C117.052 28.2977 115.884 26.9431 115.884 24.7473V16.7362H118.849V23.5798C118.849 25.1451 119.666 25.6585 120.927 25.6585C122.071 25.6585 122.983 25.028 123.497 24.3731V16.7362H126.463V28.2977H123.497ZM128.69 22.3652C128.69 18.9092 131.212 16.4563 134.67 16.4563C136.982 16.4563 138.383 17.4611 139.131 18.4886L137.191 20.3093C136.655 19.5153 135.838 19.0955 134.81 19.0955C133.011 19.0955 131.751 20.4037 131.751 22.366C131.751 24.3267 133.011 25.6585 134.81 25.6585C135.838 25.6585 136.655 25.1915 137.191 24.4203L139.131 26.2426C138.383 27.2702 136.982 28.2977 134.67 28.2977C131.212 28.2977 128.69 25.8456 128.69 22.3652ZM141.681 25.1915V19.329H139.813V16.7362H141.681V13.6528H144.648V16.7362H146.935V19.329H144.648V24.3975C144.648 25.1215 145.02 25.6585 145.675 25.6585C146.118 25.6585 146.541 25.495 146.702 25.3087L147.334 27.5728C146.891 27.9714 146.096 28.2977 144.857 28.2977C142.779 28.2977 141.681 27.2238 141.681 25.1915ZM165.935 28.2977V21.454H158.577V28.2977H155.263V12.439H158.577V18.5577H165.935V12.4398H169.275V28.2977H165.935ZM179.889 28.2977V26.5925C179.119 27.4337 177.764 28.2977 175.919 28.2977C173.443 28.2977 172.276 26.9431 172.276 24.7473V16.7362H175.241V23.5798C175.241 25.1451 176.058 25.6585 177.32 25.6585C178.464 25.6585 179.376 25.028 179.889 24.3731V16.7362H182.856V28.2977H179.889ZM193.417 28.2977V21.1986C193.417 19.6333 192.602 19.0963 191.339 19.0963C190.172 19.0963 189.285 19.7504 188.77 20.4045V28.2985H185.806V16.7362H188.77V18.1843C189.495 17.3439 190.896 16.4563 192.718 16.4563C195.217 16.4563 196.408 17.8573 196.408 20.0523V28.2977H193.418H193.417ZM199.942 25.1915V19.329H198.076V16.7362H199.943V13.6528H202.91V16.7362H205.198V19.329H202.91V24.3975C202.91 25.1215 203.282 25.6585 203.936 25.6585C204.38 25.6585 204.802 25.495 204.965 25.3087L205.595 27.5728C205.152 27.9714 204.356 28.2977 203.119 28.2977C201.04 28.2977 199.943 27.2238 199.943 25.1915" fill="currentColor"/>
                    </svg>
                  </.page_link>
                  <.page_link path={"/"} class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
                    <svg class="h-11" viewBox="0 0 120 41" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M20.058 40.5994C31.0322 40.5994 39.9286 31.7031 39.9286 20.7289C39.9286 9.75473 31.0322 0.858398 20.058 0.858398C9.08385 0.858398 0.1875 9.75473 0.1875 20.7289C0.1875 31.7031 9.08385 40.5994 20.058 40.5994Z" fill="currentColor"/>
                      <path d="M33.3139 20.729C33.3139 19.1166 32.0101 17.8362 30.4211 17.8362C29.6388 17.8362 28.9272 18.1442 28.4056 18.6424C26.414 17.2196 23.687 16.2949 20.6518 16.1765L21.9796 9.96387L26.2951 10.8885C26.3429 11.9793 27.2437 12.8567 28.3584 12.8567C29.4965 12.8567 30.4211 11.9321 30.4211 10.7935C30.4211 9.65536 29.4965 8.73071 28.3584 8.73071C27.5522 8.73071 26.8406 9.20497 26.5086 9.89271L21.6954 8.87303C21.553 8.84917 21.4107 8.87303 21.3157 8.94419C21.1972 9.01535 21.1261 9.13381 21.1026 9.27613L19.6321 16.1999C16.5497 16.2949 13.7753 17.2196 11.7599 18.6662C11.2171 18.1478 10.495 17.8589 9.74439 17.86C8.13201 17.86 6.85156 19.1639 6.85156 20.7529C6.85156 21.9383 7.56272 22.9341 8.55897 23.3849C8.51123 23.6691 8.48781 23.9538 8.48781 24.2623C8.48781 28.7197 13.6807 32.348 20.083 32.348C26.4852 32.348 31.6781 28.7436 31.6781 24.2623C31.6781 23.9776 31.6543 23.6691 31.607 23.3849C32.6028 22.9341 33.3139 21.9144 33.3139 20.729ZM13.4434 22.7918C13.4434 21.6536 14.368 20.729 15.5066 20.729C16.6447 20.729 17.5694 21.6536 17.5694 22.7918C17.5694 23.9299 16.6447 24.855 15.5066 24.855C14.368 24.8784 13.4434 23.9299 13.4434 22.7918ZM24.9913 28.2694C23.5685 29.6921 20.8653 29.7872 20.083 29.7872C19.2768 29.7872 16.5736 29.6683 15.1742 28.2694C14.9612 28.0559 14.9612 27.7239 15.1742 27.5105C15.3877 27.2974 15.7196 27.2974 15.9331 27.5105C16.8343 28.4117 18.7314 28.7197 20.083 28.7197C21.4346 28.7197 23.355 28.4117 24.2324 27.5105C24.4459 27.2974 24.7778 27.2974 24.9913 27.5105C25.1809 27.7239 25.1809 28.0559 24.9913 28.2694ZM24.6116 24.8784C23.4735 24.8784 22.5488 23.9538 22.5488 22.8156C22.5488 21.6775 23.4735 20.7529 24.6116 20.7529C25.7502 20.7529 26.6748 21.6775 26.6748 22.8156C26.6748 23.9299 25.7502 24.8784 24.6116 24.8784Z" fill="white"/>
                      <path d="M108.412 16.6268C109.8 16.6268 110.926 15.5014 110.926 14.1132C110.926 12.725 109.8 11.5996 108.412 11.5996C107.024 11.5996 105.898 12.725 105.898 14.1132C105.898 15.5014 107.024 16.6268 108.412 16.6268Z" fill="currentColor"/>
                      <path d="M72.5114 24.8309C73.7446 24.8309 74.4557 23.9063 74.4084 23.0051C74.385 22.5308 74.3373 22.2223 74.29 21.9854C73.5311 18.7133 70.8756 16.2943 67.7216 16.2943C63.9753 16.2943 60.9401 19.6853 60.9401 23.8586C60.9401 28.0318 63.9753 31.4228 67.7216 31.4228C70.0694 31.4228 71.753 30.5693 72.9622 29.2177C73.5549 28.5538 73.4365 27.5341 72.7249 27.036C72.1322 26.6329 71.3972 26.7752 70.8517 27.2256C70.3302 27.6765 69.3344 28.5772 67.7216 28.5772C65.825 28.5772 64.2126 26.941 63.8568 24.7832H72.5114V24.8309ZM67.6981 19.1637C69.4051 19.1637 70.8756 20.4915 71.421 22.3173H63.9752C64.5207 20.468 65.9907 19.1637 67.6981 19.1637ZM61.0824 17.7883C61.0824 17.0771 60.5609 16.5078 59.897 16.3894C57.8338 16.0813 55.8895 16.8397 54.7752 18.2391V18.049C54.7752 17.1717 54.0636 16.6267 53.3525 16.6267C52.5697 16.6267 51.9297 17.2667 51.9297 18.049V29.6681C51.9297 30.427 52.4985 31.0908 53.2574 31.1381C54.0875 31.1854 54.7752 30.5454 54.7752 29.7154V23.7162C54.7752 21.0608 56.7668 18.8791 59.5173 19.1876H59.802C60.5131 19.1399 61.0824 18.5233 61.0824 17.7883ZM109.834 19.306C109.834 18.5233 109.194 17.8833 108.412 17.8833C107.629 17.8833 106.989 18.5233 106.989 19.306V29.7154C106.989 30.4981 107.629 31.1381 108.412 31.1381C109.194 31.1381 109.834 30.4981 109.834 29.7154V19.306ZM88.6829 11.4338C88.6829 10.651 88.0429 10.011 87.2602 10.011C86.4779 10.011 85.8379 10.651 85.8379 11.4338V17.7648C84.8655 16.7924 83.6562 16.3182 82.2096 16.3182C78.4632 16.3182 75.4281 19.7091 75.4281 23.8824C75.4281 28.0557 78.4632 31.4466 82.2096 31.4466C83.6562 31.4466 84.8893 30.9485 85.8613 29.9761C85.9797 30.6405 86.5729 31.1381 87.2602 31.1381C88.0429 31.1381 88.6829 30.4981 88.6829 29.7154V11.4338ZM82.2334 28.6245C80.0518 28.6245 78.2971 26.5145 78.2971 23.8824C78.2971 21.2742 80.0518 19.1399 82.2334 19.1399C84.4151 19.1399 86.1698 21.2504 86.1698 23.8824C86.1698 26.5145 84.3912 28.6245 82.2334 28.6245ZM103.527 11.4338C103.527 10.651 102.887 10.011 102.104 10.011C101.322 10.011 100.681 10.651 100.681 11.4338V17.7648C99.7093 16.7924 98.5 16.3182 97.0534 16.3182C93.307 16.3182 90.2719 19.7091 90.2719 23.8824C90.2719 28.0557 93.307 31.4466 97.0534 31.4466C98.5 31.4466 99.7327 30.9485 100.705 29.9761C100.824 30.6405 101.416 31.1381 102.104 31.1381C102.887 31.1381 103.527 30.4981 103.527 29.7154V11.4338ZM97.0534 28.6245C94.8717 28.6245 93.1174 26.5145 93.1174 23.8824C93.1174 21.2742 94.8717 19.1399 97.0534 19.1399C99.235 19.1399 100.99 21.2504 100.99 23.8824C100.99 26.5145 99.235 28.6245 97.0534 28.6245ZM117.042 29.7392V19.1637H118.299C118.963 19.1637 119.556 18.6656 119.603 17.9779C119.651 17.2428 119.058 16.6267 118.347 16.6267H117.042V14.6347C117.042 13.8758 116.474 13.2119 115.715 13.1646C114.885 13.1173 114.197 13.7573 114.197 14.5874V16.6501H113.011C112.348 16.6501 111.755 17.1483 111.708 17.836C111.66 18.571 112.253 19.1876 112.964 19.1876H114.173V29.7631C114.173 30.5454 114.814 31.1854 115.596 31.1854C116.426 31.1381 117.042 30.5216 117.042 29.7392Z" fill="currentColor"/>
                    </svg>
                  </.page_link>
                </div>
              </div>
            </div>
          </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_hero_with_image",
          description: "Renders an image next to the heading and CTA buttons to improve the visual impact of the website's first visit.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_hero_with_image",
          template: """
          <section class="bg-white dark:bg-gray-900">
            <div class="grid max-w-screen-xl px-4 py-8 mx-auto lg:gap-8 xl:gap-0 lg:py-16 lg:grid-cols-12">
              <div class="mr-auto place-self-center lg:col-span-7">
                <h1 class="max-w-2xl mb-4 text-4xl font-extrabold tracking-tight leading-none md:text-5xl xl:text-6xl dark:text-white">
                  Payments tool for software companies
                </h1>
                <p class="max-w-2xl mb-6 font-light text-gray-500 lg:mb-8 md:text-lg lg:text-xl dark:text-gray-400">
                 From checkout to global sales tax compliance, companies around the world use Flowbite to simplify their payment stack.
                </p>
                <.page_link path={"/"} class="inline-flex items-center justify-center px-5 py-3 mr-3 text-base font-medium text-center text-white rounded-lg bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
                  Get started
                  <svg class="w-5 h-5 ml-2 -mr-1" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path></svg>
                </.page_link>
                <.page_link path={"/"} class="inline-flex items-center justify-center px-5 py-3 text-base font-medium text-center text-gray-900 border border-gray-300 rounded-lg hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-700 dark:hover:bg-gray-700 dark:focus:ring-gray-800">
                  Speak to Sales
                </.page_link>
              </div>
              <div class="hidden lg:mt-0 lg:col-span-5 lg:flex">
                <img src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/hero/phone-mockup.png" alt="mockup">
              </div>
            </div>
          </section>
          """,
          example: """
          <section class="bg-white dark:bg-gray-900">
            <div class="grid max-w-screen-xl px-4 py-8 mx-auto lg:gap-8 xl:gap-0 lg:py-16 lg:grid-cols-12">
              <div class="mr-auto place-self-center lg:col-span-7">
                <h1 class="max-w-2xl mb-4 text-4xl font-extrabold tracking-tight leading-none md:text-5xl xl:text-6xl dark:text-white">
                  Payments tool for software companies
                </h1>
                <p class="max-w-2xl mb-6 font-light text-gray-500 lg:mb-8 md:text-lg lg:text-xl dark:text-gray-400">
                 From checkout to global sales tax compliance, companies around the world use Flowbite to simplify their payment stack.
                </p>
                <.page_link path={"/"} class="inline-flex items-center justify-center px-5 py-3 mr-3 text-base font-medium text-center text-white rounded-lg bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
                  Get started
                  <svg class="w-5 h-5 ml-2 -mr-1" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path></svg>
                </.page_link>
                <.page_link path={"/"} class="inline-flex items-center justify-center px-5 py-3 text-base font-medium text-center text-gray-900 border border-gray-300 rounded-lg hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-700 dark:hover:bg-gray-700 dark:focus:ring-gray-800">
                  Speak to Sales
                </.page_link>
              </div>
              <div class="hidden lg:mt-0 lg:col-span-5 lg:flex">
                <img src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/hero/phone-mockup.png" alt="mockup">
              </div>
            </div>
          </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_header",
          description: "Renders a heading with a paragraph and a CTA link anywhere on your page relative to other sections.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_header",
          template: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl lg:py-16 lg:px-6">
              <div class="max-w-screen-lg text-gray-500 sm:text-lg dark:text-gray-400">
                <h2 class="mb-4 text-4xl tracking-tight font-bold text-gray-900 dark:text-white">
                  Powering innovation at <span class="font-extrabold">200,000+</span> companies worldwide
                </h2>
                <p class="mb-4 font-light">
                  Track work across the enterprise through an open, collaborative platform. Link issues across Jira and ingest data from other software development tools, so your IT support and operations teams have richer contextual information to rapidly respond to requests, incidents, and changes.
                </p>
                <p class="mb-4 font-medium">
                  Deliver great service experiences fast - without the complexity of traditional ITSM solutions.Accelerate critical development work, eliminate toil, and deploy changes with ease.
                </p>
                <.page_link path={"/"} class="inline-flex items-center font-medium text-neutral-600 hover:text-neutral-800 dark:text-neutral-500 dark:hover:text-neutral-700">
                  Learn more
                  <svg class="ml-1 w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
                  </svg>
                </.page_link>
              </div>
            </div>
          </section>
          """,
          example: """
          <section class="bg-white dark:bg-gray-900">
            <div class="py-8 px-4 mx-auto max-w-screen-xl lg:py-16 lg:px-6">
              <div class="max-w-screen-lg text-gray-500 sm:text-lg dark:text-gray-400">
                <h2 class="mb-4 text-4xl tracking-tight font-bold text-gray-900 dark:text-white">
                  Powering innovation at <span class="font-extrabold">200,000+</span> companies worldwide
                </h2>
                <p class="mb-4 font-light">
                  Track work across the enterprise through an open, collaborative platform. Link issues across Jira and ingest data from other software development tools, so your IT support and operations teams have richer contextual information to rapidly respond to requests, incidents, and changes.
                </p>
                <p class="mb-4 font-medium">
                  Deliver great service experiences fast - without the complexity of traditional ITSM solutions.Accelerate critical development work, eliminate toil, and deploy changes with ease.
                </p>
                <.page_link path={"/"} class="inline-flex items-center font-medium text-neutral-600 hover:text-neutral-800 dark:text-neutral-500 dark:hover:text-neutral-700">
                  Learn more
                  <svg class="ml-1 w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
                  </svg>
                </.page_link>
              </div>
            </div>
          </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_header_with_image",
          description: "Renders a couple of images next to a heading and paragraph to provide visual impact to your users.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_header_with_image",
          template: """
          <section class="bg-white dark:bg-gray-900">
            <div class="gap-16 items-center py-8 px-4 mx-auto max-w-screen-xl lg:grid lg:grid-cols-2 lg:py-16 lg:px-6">
              <div class="font-light text-gray-500 sm:text-lg dark:text-gray-400">
                  <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">
                    We didn't reinvent the wheel
                  </h2>
                  <p class="mb-4">
                    We are strategists, designers and developers. Innovators and problem solvers. Small enough to be simple and quick, but big enough to deliver the scope you want at the pace you need. Small enough to be simple and quick, but big enough to deliver the scope you want at the pace you need.
                  </p>
                  <p>
                    We are strategists, designers and developers. Innovators and problem solvers. Small enough to be simple and quick.
                  </p>
              </div>
              <div class="grid grid-cols-2 gap-4 mt-8">
                <img class="w-full rounded-lg" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/content/office-long-2.png" alt="office content 1">
                <img class="mt-4 w-full lg:mt-10 rounded-lg" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/content/office-long-1.png" alt="office content 2">
              </div>
            </div>
          </section>
          """,
          example: """
          <section class="bg-white dark:bg-gray-900">
            <div class="gap-16 items-center py-8 px-4 mx-auto max-w-screen-xl lg:grid lg:grid-cols-2 lg:py-16 lg:px-6">
              <div class="font-light text-gray-500 sm:text-lg dark:text-gray-400">
                  <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">
                    We didn't reinvent the wheel
                  </h2>
                  <p class="mb-4">
                    We are strategists, designers and developers. Innovators and problem solvers. Small enough to be simple and quick, but big enough to deliver the scope you want at the pace you need. Small enough to be simple and quick, but big enough to deliver the scope you want at the pace you need.
                  </p>
                  <p>
                    We are strategists, designers and developers. Innovators and problem solvers. Small enough to be simple and quick.
                  </p>
              </div>
              <div class="grid grid-cols-2 gap-4 mt-8">
                <img class="w-full rounded-lg" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/content/office-long-2.png" alt="office content 1">
                <img class="mt-4 w-full lg:mt-10 rounded-lg" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/content/office-long-1.png" alt="office content 2">
              </div>
            </div>
          </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_feature_list",
          description:
            "Renders an example of feature items based on a grid layout where you can show up to three items on a row featuring an icon, title and description.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_feature_list",
          template: """
            <section class="bg-white dark:bg-gray-900">
              <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
                  <div class="max-w-screen-md mb-8 lg:mb-16">
                      <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">Designed for business teams like yours</h2>
                      <p class="text-gray-500 sm:text-xl dark:text-gray-400">Here at Flowbite we focus on markets where technology, innovation, and capital can unlock long-term value and drive economic growth.</p>
                  </div>
                  <div class="space-y-8 md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-12 md:space-y-0">
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 0l-2 2a1 1 0 101.414 1.414L8 10.414l1.293 1.293a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Marketing</h3>
                          <p class="text-gray-500 dark:text-gray-400">Plan it, create it, launch it. Collaborate seamlessly with all  the organization and hit your marketing goals every month with our marketing plan.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M10.394 2.08a1 1 0 00-.788 0l-7 3a1 1 0 000 1.84L5.25 8.051a.999.999 0 01.356-.257l4-1.714a1 1 0 11.788 1.838L7.667 9.088l1.94.831a1 1 0 00.787 0l7-3a1 1 0 000-1.838l-7-3zM3.31 9.397L5 10.12v4.102a8.969 8.969 0 00-1.05-.174 1 1 0 01-.89-.89 11.115 11.115 0 01.25-3.762zM9.3 16.573A9.026 9.026 0 007 14.935v-3.957l1.818.78a3 3 0 002.364 0l5.508-2.361a11.026 11.026 0 01.25 3.762 1 1 0 01-.89.89 8.968 8.968 0 00-5.35 2.524 1 1 0 01-1.4 0zM6 18a1 1 0 001-1v-2.065a8.935 8.935 0 00-2-.712V17a1 1 0 001 1z"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Legal</h3>
                          <p class="text-gray-500 dark:text-gray-400">Protect your organization, devices and stay compliant with our structured workflows and custom permissions made for you.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M6 6V5a3 3 0 013-3h2a3 3 0 013 3v1h2a2 2 0 012 2v3.57A22.952 22.952 0 0110 13a22.95 22.95 0 01-8-1.43V8a2 2 0 012-2h2zm2-1a1 1 0 011-1h2a1 1 0 011 1v1H8V5zm1 5a1 1 0 011-1h.01a1 1 0 110 2H10a1 1 0 01-1-1z" clip-rule="evenodd"></path><path d="M2 13.692V16a2 2 0 002 2h12a2 2 0 002-2v-2.308A24.974 24.974 0 0110 15c-2.796 0-5.487-.46-8-1.308z"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Business Automation</h3>
                          <p class="text-gray-500 dark:text-gray-400">Auto-assign tasks, send Slack messages, and much more. Now power up with hundreds of new templates to help you get started.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"></path><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5z" clip-rule="evenodd"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Finance</h3>
                          <p class="text-gray-500 dark:text-gray-400">Audit-proof software built for critical financial operations like month-end close and quarterly budgeting.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M7 3a1 1 0 000 2h6a1 1 0 100-2H7zM4 7a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zM2 11a2 2 0 012-2h12a2 2 0 012 2v4a2 2 0 01-2 2H4a2 2 0 01-2-2v-4z"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Enterprise Design</h3>
                          <p class="text-gray-500 dark:text-gray-400">Craft beautiful, delightful experiences for both marketing and product with real cross-company collaboration.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Operations</h3>
                          <p class="text-gray-500 dark:text-gray-400">Keep your company’s lights on with customizable, iterative, and structured workflows built for all efficient teams and individual.</p>
                      </div>
                  </div>
              </div>
            </section>
          """,
          example: """
            <section class="bg-white dark:bg-gray-900">
              <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
                  <div class="max-w-screen-md mb-8 lg:mb-16">
                      <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">Designed for business teams like yours</h2>
                      <p class="text-gray-500 sm:text-xl dark:text-gray-400">Here at Flowbite we focus on markets where technology, innovation, and capital can unlock long-term value and drive economic growth.</p>
                  </div>
                  <div class="space-y-8 md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-12 md:space-y-0">
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 0l-2 2a1 1 0 101.414 1.414L8 10.414l1.293 1.293a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Marketing</h3>
                          <p class="text-gray-500 dark:text-gray-400">Plan it, create it, launch it. Collaborate seamlessly with all  the organization and hit your marketing goals every month with our marketing plan.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M10.394 2.08a1 1 0 00-.788 0l-7 3a1 1 0 000 1.84L5.25 8.051a.999.999 0 01.356-.257l4-1.714a1 1 0 11.788 1.838L7.667 9.088l1.94.831a1 1 0 00.787 0l7-3a1 1 0 000-1.838l-7-3zM3.31 9.397L5 10.12v4.102a8.969 8.969 0 00-1.05-.174 1 1 0 01-.89-.89 11.115 11.115 0 01.25-3.762zM9.3 16.573A9.026 9.026 0 007 14.935v-3.957l1.818.78a3 3 0 002.364 0l5.508-2.361a11.026 11.026 0 01.25 3.762 1 1 0 01-.89.89 8.968 8.968 0 00-5.35 2.524 1 1 0 01-1.4 0zM6 18a1 1 0 001-1v-2.065a8.935 8.935 0 00-2-.712V17a1 1 0 001 1z"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Legal</h3>
                          <p class="text-gray-500 dark:text-gray-400">Protect your organization, devices and stay compliant with our structured workflows and custom permissions made for you.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M6 6V5a3 3 0 013-3h2a3 3 0 013 3v1h2a2 2 0 012 2v3.57A22.952 22.952 0 0110 13a22.95 22.95 0 01-8-1.43V8a2 2 0 012-2h2zm2-1a1 1 0 011-1h2a1 1 0 011 1v1H8V5zm1 5a1 1 0 011-1h.01a1 1 0 110 2H10a1 1 0 01-1-1z" clip-rule="evenodd"></path><path d="M2 13.692V16a2 2 0 002 2h12a2 2 0 002-2v-2.308A24.974 24.974 0 0110 15c-2.796 0-5.487-.46-8-1.308z"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Business Automation</h3>
                          <p class="text-gray-500 dark:text-gray-400">Auto-assign tasks, send Slack messages, and much more. Now power up with hundreds of new templates to help you get started.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"></path><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5z" clip-rule="evenodd"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Finance</h3>
                          <p class="text-gray-500 dark:text-gray-400">Audit-proof software built for critical financial operations like month-end close and quarterly budgeting.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M7 3a1 1 0 000 2h6a1 1 0 100-2H7zM4 7a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zM2 11a2 2 0 012-2h12a2 2 0 012 2v4a2 2 0 01-2 2H4a2 2 0 01-2-2v-4z"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Enterprise Design</h3>
                          <p class="text-gray-500 dark:text-gray-400">Craft beautiful, delightful experiences for both marketing and product with real cross-company collaboration.</p>
                      </div>
                      <div>
                          <div class="flex justify-center items-center mb-4 w-10 h-10 rounded-full bg-neutral-100 lg:h-12 lg:w-12 dark:bg-neutral-900">
                              <svg class="w-5 h-5 text-neutral-600 lg:w-6 lg:h-6 dark:text-neutral-300" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd"></path></svg>
                          </div>
                          <h3 class="mb-2 text-xl font-bold dark:text-white">Operations</h3>
                          <p class="text-gray-500 dark:text-gray-400">Keep your company’s lights on with customizable, iterative, and structured workflows built for all efficient teams and individual.</p>
                      </div>
                  </div>
              </div>
            </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_testimonial",
          description: "Renders an example of a testimonial based on a blockquote element and show the text, customer avatar, name, and occupation.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_testimonial",
          template: """
            <section class="bg-white dark:bg-gray-900">
              <div class="max-w-screen-xl px-4 py-8 mx-auto text-center lg:py-16 lg:px-6">
                  <figure class="max-w-screen-md mx-auto">
                      <svg class="h-12 mx-auto mb-3 text-gray-400 dark:text-gray-600" viewBox="0 0 24 27" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M14.017 18L14.017 10.609C14.017 4.905 17.748 1.039 23 0L23.995 2.151C21.563 3.068 20 5.789 20 8H24V18H14.017ZM0 18V10.609C0 4.905 3.748 1.038 9 0L9.996 2.151C7.563 3.068 6 5.789 6 8H9.983L9.983 18L0 18Z" fill="currentColor"/>
                      </svg>
                      <blockquote>
                          <p class="text-2xl font-medium text-gray-900 dark:text-white">"Flowbite is just awesome. It contains tons of predesigned components and pages starting from login screen to complex dashboard. Perfect choice for your next SaaS application."</p>
                      </blockquote>
                      <figcaption class="flex items-center justify-center mt-6 space-x-3">
                          <img class="w-6 h-6 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/michael-gouch.png" alt="profile picture">
                          <div class="flex items-center divide-x-2 divide-gray-500 dark:divide-gray-700">
                              <div class="pr-3 font-medium text-gray-900 dark:text-white">Micheal Gough</div>
                              <div class="pl-3 text-sm font-light text-gray-500 dark:text-gray-400">CEO at Google</div>
                          </div>
                      </figcaption>
                  </figure>
              </div>
            </section>
          """,
          example: """
            <section class="bg-white dark:bg-gray-900">
              <div class="max-w-screen-xl px-4 py-8 mx-auto text-center lg:py-16 lg:px-6">
                  <figure class="max-w-screen-md mx-auto">
                      <svg class="h-12 mx-auto mb-3 text-gray-400 dark:text-gray-600" viewBox="0 0 24 27" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M14.017 18L14.017 10.609C14.017 4.905 17.748 1.039 23 0L23.995 2.151C21.563 3.068 20 5.789 20 8H24V18H14.017ZM0 18V10.609C0 4.905 3.748 1.038 9 0L9.996 2.151C7.563 3.068 6 5.789 6 8H9.983L9.983 18L0 18Z" fill="currentColor"/>
                      </svg>
                      <blockquote>
                          <p class="text-2xl font-medium text-gray-900 dark:text-white">"Flowbite is just awesome. It contains tons of predesigned components and pages starting from login screen to complex dashboard. Perfect choice for your next SaaS application."</p>
                      </blockquote>
                      <figcaption class="flex items-center justify-center mt-6 space-x-3">
                          <img class="w-6 h-6 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/michael-gouch.png" alt="profile picture">
                          <div class="flex items-center divide-x-2 divide-gray-500 dark:divide-gray-700">
                              <div class="pr-3 font-medium text-gray-900 dark:text-white">Micheal Gough</div>
                              <div class="pl-3 text-sm font-light text-gray-500 dark:text-gray-400">CEO at Google</div>
                          </div>
                      </figcaption>
                  </figure>
              </div>
            </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_testimonial_cards",
          description:
            "Renders an example of testimonial cards up to two items on a row and show the title, description, avatar, name, and occupation.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_testimonial_cards",
          template: """
            <section class="bg-white dark:bg-gray-900">
              <div class="py-8 px-4 mx-auto max-w-screen-xl text-center lg:py-16 lg:px-6">
                  <div class="mx-auto max-w-screen-sm">
                      <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">Testimonials</h2>
                      <p class="mb-8 font-light text-gray-500 lg:mb-16 sm:text-xl dark:text-gray-400">Explore the whole collection of open-source web components and elements built with the utility classes from Tailwind</p>
                  </div>
                  <div class="grid mb-8 lg:mb-12 lg:grid-cols-2">
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-b border-gray-200 md:p-12 lg:border-r dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Speechless with how easy this was to integrate</h3>
                              <p class="my-4">"I recently got my hands on Flowbite Pro, and holy crap, I'm speechless with how easy this was to integrate within my application. Most templates are a pain, code is scattered, and near impossible to theme.</p>
                              <p class="my-4">Flowbite has code in one place and I'm not joking when I say it took me a matter of minutes to copy the code, customise it and integrate within a Laravel + Vue application.</p>
                              <p class="my-4">If you care for your time, I hands down would go with this."</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/karen-nelson.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Bonnie Green</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">Developer at Open AI</div>
                              </div>
                          </figcaption>
                      </figure>
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-b border-gray-200 md:p-12 dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Solid foundation for any project</h3>
                              <p class="my-4">"FlowBite provides a robust set of design tokens and components based on the popular Tailwind CSS framework. From the most used UI components like forms and navigation bars to the whole app screens designed both for desktop and mobile, this UI kit provides a solid foundation for any project.</p>
                              <p class="my-4">Designing with Figma components that can be easily translated to the utility classes of Tailwind CSS is a huge timesaver!"</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/roberta-casas.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Roberta Casas</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">Lead designer at Dropbox</div>
                              </div>
                          </figcaption>
                      </figure>
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-b border-gray-200 lg:border-b-0 md:p-12 lg:border-r dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Mindblowing workflow and variants</h3>
                              <p class="my-4">"As someone who mainly designs in the browser, I've been a casual user of Figma, but as soon as I saw and started playing with FlowBite my mind was 🤯.</p>
                              <p class="my-4">Everything is so well structured and simple to use (I've learnt so much about Figma by just using the toolkit).</p>
                              <p class="my-4">Aesthetically, the well designed components are beautiful and will undoubtedly level up your next application."</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/jese-leos.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Jese Leos</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">Software Engineer at Facebook</div>
                              </div>
                          </figcaption>
                      </figure>
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-gray-200 md:p-12 dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Efficient Collaborating</h3>
                              <p class="my-4">"This is a very complex and beautiful set of elements. Under the hood it comes with the best things from 2 different worlds: Figma and Tailwind.</p>
                              <p class="my-4">You have many examples that can be used to create a fast prototype for your team."</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/joseph-mcfall.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Joseph McFall</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">CTO at Google</div>
                              </div>
                          </figcaption>
                      </figure>
                  </div>
                  <div class="text-center">
                    <.page_link path={"/"} class="py-2.5 px-5 mr-2 mb-2 text-sm font-medium text-gray-900 focus:outline-none bg-white rounded-lg border border-gray-200 hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-4 focus:ring-gray-200 dark:focus:ring-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:text-white dark:hover:bg-gray-700">Show more...</.page_link>
                  </div>
              </div>
            </section>
          """,
          example: """
            <section class="bg-white dark:bg-gray-900">
              <div class="py-8 px-4 mx-auto max-w-screen-xl text-center lg:py-16 lg:px-6">
                  <div class="mx-auto max-w-screen-sm">
                      <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">Testimonials</h2>
                      <p class="mb-8 font-light text-gray-500 lg:mb-16 sm:text-xl dark:text-gray-400">Explore the whole collection of open-source web components and elements built with the utility classes from Tailwind</p>
                  </div>
                  <div class="grid mb-8 lg:mb-12 lg:grid-cols-2">
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-b border-gray-200 md:p-12 lg:border-r dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Speechless with how easy this was to integrate</h3>
                              <p class="my-4">"I recently got my hands on Flowbite Pro, and holy crap, I'm speechless with how easy this was to integrate within my application. Most templates are a pain, code is scattered, and near impossible to theme.</p>
                              <p class="my-4">Flowbite has code in one place and I'm not joking when I say it took me a matter of minutes to copy the code, customise it and integrate within a Laravel + Vue application.</p>
                              <p class="my-4">If you care for your time, I hands down would go with this."</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/karen-nelson.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Bonnie Green</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">Developer at Open AI</div>
                              </div>
                          </figcaption>
                      </figure>
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-b border-gray-200 md:p-12 dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Solid foundation for any project</h3>
                              <p class="my-4">"FlowBite provides a robust set of design tokens and components based on the popular Tailwind CSS framework. From the most used UI components like forms and navigation bars to the whole app screens designed both for desktop and mobile, this UI kit provides a solid foundation for any project.</p>
                              <p class="my-4">Designing with Figma components that can be easily translated to the utility classes of Tailwind CSS is a huge timesaver!"</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/roberta-casas.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Roberta Casas</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">Lead designer at Dropbox</div>
                              </div>
                          </figcaption>
                      </figure>
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-b border-gray-200 lg:border-b-0 md:p-12 lg:border-r dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Mindblowing workflow and variants</h3>
                              <p class="my-4">"As someone who mainly designs in the browser, I've been a casual user of Figma, but as soon as I saw and started playing with FlowBite my mind was 🤯.</p>
                              <p class="my-4">Everything is so well structured and simple to use (I've learnt so much about Figma by just using the toolkit).</p>
                              <p class="my-4">Aesthetically, the well designed components are beautiful and will undoubtedly level up your next application."</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/jese-leos.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Jese Leos</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">Software Engineer at Facebook</div>
                              </div>
                          </figcaption>
                      </figure>
                      <figure class="flex flex-col justify-center items-center p-8 text-center bg-gray-50 border-gray-200 md:p-12 dark:bg-gray-800 dark:border-gray-700">
                          <blockquote class="mx-auto mb-8 max-w-2xl text-gray-500 dark:text-gray-400">
                              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Efficient Collaborating</h3>
                              <p class="my-4">"This is a very complex and beautiful set of elements. Under the hood it comes with the best things from 2 different worlds: Figma and Tailwind.</p>
                              <p class="my-4">You have many examples that can be used to create a fast prototype for your team."</p>
                          </blockquote>
                          <figcaption class="flex justify-center items-center space-x-3">
                              <img class="w-9 h-9 rounded-full" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/avatars/joseph-mcfall.png" alt="profile picture">
                              <div class="space-y-0.5 font-medium dark:text-white text-left">
                                  <div>Joseph McFall</div>
                                  <div class="text-sm font-light text-gray-500 dark:text-gray-400">CTO at Google</div>
                              </div>
                          </figcaption>
                      </figure>
                  </div>
                  <div class="text-center">
                    <.page_link path={"/"} class="py-2.5 px-5 mr-2 mb-2 text-sm font-medium text-gray-900 focus:outline-none bg-white rounded-lg border border-gray-200 hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-4 focus:ring-gray-200 dark:focus:ring-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:text-white dark:hover:bg-gray-700">Show more...</.page_link>
                  </div>
              </div>
            </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_customer_logos",
          description:
            "Renders an example to show a list of logos of the companies that have used your product or worked with to provide strong social proof to your website visitors.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_customer_logos",
          template: """
            <section class="bg-white dark:bg-gray-900">
                <div class="py-8 lg:py-16 mx-auto max-w-screen-xl px-4">
                    <h2 class="mb-8 lg:mb-16 text-3xl font-extrabold tracking-tight leading-tight text-center text-gray-900 dark:text-white md:text-4xl">You’ll be in good company</h2>
                    <div class="grid grid-cols-2 gap-8 text-gray-500 sm:gap-12 md:grid-cols-3 lg:grid-cols-6 dark:text-gray-400">
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 125 35" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M64.828 7.11521C64.828 8.52061 63.6775 9.65275 62.2492 9.65275C60.8209 9.65275 59.6704 8.52061 59.6704 7.11521C59.6704 5.70981 60.7813 4.57766 62.2492 4.57766C63.7171 4.6167 64.828 5.74883 64.828 7.11521ZM54.1953 12.2293C54.1953 12.4636 54.1953 12.854 54.1953 12.854C54.1953 12.854 52.9655 11.2923 50.3469 11.2923C46.0225 11.2923 42.6502 14.5327 42.6502 19.0221C42.6502 23.4726 45.9829 26.7518 50.3469 26.7518C53.0051 26.7518 54.1953 25.1513 54.1953 25.1513V25.815C54.1953 26.1272 54.4334 26.3615 54.7508 26.3615H57.9644V11.6828C57.9644 11.6828 55.0285 11.6828 54.7508 11.6828C54.4334 11.6828 54.1953 11.956 54.1953 12.2293ZM54.1953 21.6378C53.6002 22.4966 52.41 23.2383 50.9818 23.2383C48.4426 23.2383 46.4985 21.6768 46.4985 19.0221C46.4985 16.3675 48.4426 14.806 50.9818 14.806C52.3703 14.806 53.6399 15.5867 54.1953 16.4065V21.6378ZM60.3448 11.6828H64.1535V26.3615H60.3448V11.6828ZM117.237 11.2923C114.619 11.2923 113.389 12.854 113.389 12.854V4.6167H109.58V26.3615C109.58 26.3615 112.516 26.3615 112.794 26.3615C113.111 26.3615 113.349 26.0882 113.349 25.815V25.1513C113.349 25.1513 114.579 26.7518 117.198 26.7518C121.522 26.7518 124.895 23.4726 124.895 19.0221C124.895 14.5717 121.522 11.2923 117.237 11.2923ZM116.603 23.1993C115.135 23.1993 113.984 22.4575 113.389 21.5986V16.3675C113.984 15.5867 115.254 14.7668 116.603 14.7668C119.142 14.7668 121.086 16.3284 121.086 18.9831C121.086 21.6378 119.142 23.1993 116.603 23.1993ZM107.597 17.6557V26.4005H103.788V18.0852C103.788 15.6648 102.994 14.6888 100.852 14.6888C99.7015 14.6888 98.5113 15.2744 97.7574 16.1332V26.3615H93.9488V11.6828H96.964C97.2814 11.6828 97.5195 11.956 97.5195 12.2293V12.854C98.6302 11.7218 100.098 11.2923 101.566 11.2923C103.233 11.2923 104.621 11.7609 105.732 12.6977C107.081 13.7908 107.597 15.1962 107.597 17.6557ZM84.7048 11.2923C82.0862 11.2923 80.8564 12.854 80.8564 12.854V4.6167H77.0476V26.3615C77.0476 26.3615 79.9834 26.3615 80.2611 26.3615C80.5787 26.3615 80.8166 26.0882 80.8166 25.815V25.1513C80.8166 25.1513 82.0465 26.7518 84.665 26.7518C88.9895 26.7518 92.3617 23.4726 92.3617 19.0221C92.4015 14.5717 89.0292 11.2923 84.7048 11.2923ZM84.0699 23.1993C82.602 23.1993 81.4515 22.4575 80.8564 21.5986V16.3675C81.4515 15.5867 82.721 14.7668 84.0699 14.7668C86.6091 14.7668 88.5531 16.3284 88.5531 18.9831C88.5531 21.6378 86.6091 23.1993 84.0699 23.1993ZM73.7547 11.2923C74.9052 11.2923 75.5003 11.4876 75.5003 11.4876V14.9621C75.5003 14.9621 72.3264 13.908 70.3427 16.1332V26.4005H66.534V11.6828C66.534 11.6828 69.4699 11.6828 69.7476 11.6828C70.065 11.6828 70.3029 11.956 70.3029 12.2293V12.854C71.0171 12.0342 72.5644 11.2923 73.7547 11.2923ZM32.4423 24.4806C32.2699 24.0722 32.0976 23.6297 31.9252 23.2554C31.6493 22.6427 31.3736 22.0641 31.1322 21.5197L31.0978 21.4855C28.719 16.3804 26.1678 11.2073 23.4787 6.10219L23.3752 5.89799C23.0995 5.38748 22.8237 4.84294 22.5479 4.29839C22.2031 3.68577 21.8584 3.03913 21.3068 2.42652C20.2036 1.06516 18.6177 0.316406 16.9284 0.316406C15.2046 0.316406 13.6533 1.06516 12.5156 2.35845C11.9985 2.97107 11.6192 3.61771 11.2745 4.23032C10.9987 4.77486 10.7229 5.31941 10.4471 5.82992L10.3436 6.03413C7.68904 11.1392 5.10339 16.3124 2.7246 21.4175L2.69012 21.4855C2.44879 22.0301 2.17299 22.6087 1.89719 23.2214C1.72481 23.5957 1.55244 24.0041 1.38006 24.4466C0.93188 25.7058 0.793978 26.897 0.966355 28.1222C1.34558 30.6748 3.06935 32.8189 5.44815 33.7719C6.3445 34.1463 7.27534 34.3164 8.24065 34.3164C8.51645 34.3164 8.8612 34.2824 9.137 34.2483C10.2747 34.1122 11.4468 33.7378 12.5845 33.0912C13.9981 32.3083 15.3425 31.1852 16.8595 29.5517C18.3764 31.1852 19.7554 32.3083 21.1344 33.0912C22.2721 33.7378 23.4443 34.1122 24.5819 34.2483C24.8577 34.2824 25.2025 34.3164 25.4782 34.3164C26.4436 34.3164 27.4089 34.1463 28.2708 33.7719C30.6841 32.8189 32.3733 30.6408 32.7526 28.1222C33.0283 26.931 32.8904 25.7398 32.4423 24.4806ZM16.9259 25.893C15.1377 23.6468 13.9786 21.5327 13.5812 19.7488C13.4156 18.9891 13.3825 18.3284 13.4818 17.7338C13.5481 17.2053 13.7467 16.7429 14.0118 16.3465C14.6409 15.4546 15.7007 14.893 16.9259 14.893C18.1512 14.893 19.2441 15.4216 19.8402 16.3465C20.1051 16.7429 20.3037 17.2053 20.37 17.7338C20.4694 18.3284 20.4363 19.0221 20.2707 19.7488C19.8733 21.4995 18.7142 23.6136 16.9259 25.893ZM30.3665 27.6033C30.1305 29.3326 28.9509 30.8293 27.2993 31.4945C26.4903 31.8269 25.6139 31.9267 24.7376 31.8269C23.895 31.7273 23.0523 31.4611 22.176 30.9623C20.9624 30.2971 19.749 29.2662 18.3334 27.7363C20.558 25.0424 21.9062 22.5813 22.4118 20.3864C22.6477 19.3554 22.6815 18.4242 22.5804 17.5595C22.4456 16.7281 22.1422 15.9632 21.6703 15.298C20.6255 13.8014 18.8727 12.9367 16.9178 12.9367C14.9628 12.9367 13.21 13.8347 12.1652 15.298C11.6933 15.9632 11.39 16.7281 11.2551 17.5595C11.1203 18.4242 11.154 19.3887 11.4237 20.3864C11.9293 22.5813 13.3112 25.0757 15.5021 27.7695C14.1202 29.2994 12.873 30.3304 11.6596 30.9955C10.7832 31.4945 9.94059 31.7605 9.09795 31.8603C8.18787 31.9599 7.31152 31.8269 6.53628 31.5277C4.88468 30.8625 3.70497 29.366 3.46902 27.6365C3.36791 26.8051 3.43531 25.9737 3.77238 25.0424C3.8735 24.7098 4.04202 24.3774 4.21055 23.9782C4.4465 23.4461 4.71615 22.8807 4.9858 22.3153L5.0195 22.2489C7.34523 17.2935 9.83948 12.2383 12.4349 7.31623L12.536 7.11668C12.8056 6.61782 13.0753 6.0857 13.3449 5.58684C13.6146 5.05472 13.9179 4.55585 14.2886 4.12351C14.9965 3.32532 15.9403 2.89298 16.9852 2.89298C18.03 2.89298 18.9738 3.32532 19.6817 4.12351C20.0524 4.55585 20.3557 5.05472 20.6255 5.58684C20.8951 6.0857 21.1647 6.61782 21.4343 7.11668L21.5355 7.31623C24.0971 12.2716 26.5914 17.3267 28.9171 22.2821V22.3153C29.1867 22.8475 29.4227 23.4461 29.6924 23.9782C29.8609 24.3774 30.0294 24.7098 30.1305 25.0424C30.4003 25.9071 30.5013 26.7385 30.3665 27.6033Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 86 29" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M11.6008 10.2627V13.2312L18.6907 13.2281C18.4733 14.8653 17.9215 16.0641 17.0826 16.9031C16.0487 17.9378 14.4351 19.0766 11.6008 19.0766C7.23238 19.0766 3.81427 15.5531 3.81427 11.1808C3.81427 6.80853 7.23238 3.28487 11.6008 3.28487C13.9585 3.28487 15.6794 4.21232 16.9503 5.40473L19.0432 3.31011C17.2721 1.6161 14.9144 0.316406 11.6036 0.316406C5.62156 0.316406 0.589844 5.19338 0.589844 11.1808C0.589844 17.1682 5.62156 22.0451 11.6036 22.0451C14.8322 22.0451 17.2694 20.9852 19.1756 18.9979C21.1362 17.0356 21.7451 14.2818 21.7451 12.0546C21.7451 11.3921 21.6949 10.7802 21.5974 10.2627H11.6008ZM71.4046 21.6192V1.11445H68.4101V21.6192H71.4046ZM29.9511 22.0482C33.8151 22.0482 36.9643 19.0797 36.9643 15.0513C36.9643 10.9945 33.8151 8.05451 29.9511 8.05451C26.0857 8.05451 22.9365 10.9945 22.9365 15.0513C22.9365 19.0797 26.0857 22.0482 29.9511 22.0482ZM29.9511 10.8116C32.0691 10.8116 33.8945 12.534 33.8945 15.0513C33.8945 17.5404 32.0691 19.2911 29.9511 19.2911C27.833 19.2911 26.0076 17.5435 26.0076 15.0513C26.0076 12.534 27.833 10.8116 29.9511 10.8116ZM45.0825 22.0482C48.9465 22.0482 52.0957 19.0797 52.0957 15.0513C52.0957 10.9945 48.9465 8.05451 45.0825 8.05451C41.2171 8.05451 38.0679 10.9977 38.0679 15.0513C38.0679 19.0797 41.2171 22.0482 45.0825 22.0482ZM45.0825 10.8116C47.2005 10.8116 49.0259 12.534 49.0259 15.0513C49.0259 17.5404 47.2005 19.2911 45.0825 19.2911C42.9644 19.2911 41.139 17.5435 41.139 15.0513C41.139 12.534 42.9644 10.8116 45.0825 10.8116ZM66.5972 8.48038V21.0387C66.5972 26.2059 63.5512 28.3164 59.9519 28.3164C56.563 28.3164 54.523 26.0482 53.7539 24.1934L56.4265 23.0798C56.903 24.2186 58.0694 25.5624 59.9477 25.5624C62.2525 25.5624 63.6807 24.1397 63.6807 21.4615V20.4552H63.5734C62.8865 21.3037 61.5627 22.0451 59.892 22.0451C56.3958 22.0451 53.1923 18.9977 53.1923 15.0766C53.1923 11.1271 56.3958 8.05451 59.892 8.05451C61.5585 8.05451 62.8837 8.79579 63.5734 9.6192H63.6807V8.48038H66.5972ZM63.8981 15.0766C63.8981 12.6129 62.2553 10.8116 60.1651 10.8116C58.0471 10.8116 56.2732 12.6129 56.2732 15.0766C56.2732 17.5152 58.0471 19.2911 60.1651 19.2911C62.2553 19.2911 63.8981 17.5152 63.8981 15.0766ZM83.0747 17.3542L85.4575 18.9442C84.6883 20.083 82.835 22.0451 79.6315 22.0451C75.6602 22.0451 72.6935 18.9726 72.6935 15.0483C72.6935 10.8874 75.6853 8.05143 79.2887 8.05143C82.9172 8.05143 84.6911 10.941 85.2721 12.5026L85.5898 13.2976L76.2426 17.1713C76.9589 18.5751 78.0708 19.2912 79.6315 19.2912C81.1949 19.2912 82.2804 18.5215 83.0747 17.3542ZM75.7382 14.8369L81.9864 12.2407C81.6436 11.3668 80.6097 10.758 79.3918 10.758C77.8326 10.758 75.6602 12.1366 75.7382 14.8369Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-8 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 151 34" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <g clip-path="url(#clip0_3753_27919)"><path d="M150.059 16.1144V13.4753H146.783V9.37378L146.673 9.40894L143.596 10.3464H143.538V13.4519H138.682V11.7175C138.682 10.9207 138.869 10.2996 139.221 9.8894C139.572 9.47925 140.088 9.27417 140.721 9.27417C141.189 9.27417 141.682 9.39136 142.15 9.60229L142.268 9.64917V6.88237L142.221 6.85894C141.775 6.70073 141.166 6.6187 140.416 6.6187C139.467 6.6187 138.6 6.82964 137.838 7.24448C137.076 7.64292 136.479 8.24058 136.068 8.99058C135.646 9.74058 135.436 10.6078 135.436 11.557V13.4554H133.162V16.0921H135.447V27.2015H138.717V16.0921H143.577V23.1468C143.577 26.0531 144.943 27.5296 147.655 27.5296C148.1 27.5296 148.569 27.4734 149.038 27.3773C149.524 27.2718 149.858 27.1664 150.045 27.0609L150.092 27.0374V24.3773L149.96 24.4664C149.784 24.5835 149.561 24.6855 149.304 24.7558C149.046 24.8261 148.823 24.873 148.657 24.873C148.024 24.873 147.555 24.7089 147.267 24.3726C146.969 24.0386 146.821 23.4468 146.821 22.6148V16.1226H150.079L150.072 16.1062L150.059 16.1144ZM125.813 24.88C124.626 24.88 123.689 24.4851 123.024 23.7082C122.364 22.9289 122.028 21.8167 122.028 20.4035C122.028 18.9457 122.364 17.8019 123.028 17.0097C123.689 16.2222 124.617 15.8214 125.789 15.8214C126.925 15.8214 127.816 16.2035 128.472 16.9582C129.129 17.7175 129.457 18.8496 129.457 20.3238C129.457 21.8167 129.152 22.964 128.543 23.7304C127.933 24.4921 127.019 24.8789 125.824 24.8789L125.813 24.88ZM125.964 13.1449C123.703 13.1449 121.9 13.8082 120.616 15.1183C119.339 16.4308 118.685 18.2425 118.685 20.5089C118.685 22.6652 119.318 24.3937 120.575 25.6535C121.829 26.9191 123.536 27.5753 125.646 27.5753C127.839 27.5753 129.607 26.8957 130.886 25.5773C132.175 24.2507 132.815 22.4531 132.815 20.2417C132.815 18.055 132.206 16.3089 130.999 15.0621C129.792 13.8035 128.1 13.1683 125.96 13.1683L125.964 13.1449ZM113.397 13.1683C111.85 13.1683 110.58 13.5621 109.6 14.3402C108.625 15.123 108.124 16.1449 108.124 17.3871C108.124 18.0363 108.234 18.6058 108.447 19.098C108.658 19.5832 108.986 20.0121 109.425 20.373C109.858 20.7246 110.526 21.0996 111.417 21.4839C112.167 21.7886 112.718 22.0464 113.074 22.2574C113.425 22.4531 113.674 22.6558 113.8 22.8515C113.941 23.039 114.011 23.3085 114.011 23.625C114.011 24.5554 113.322 25.0031 111.902 25.0031C111.372 25.0031 110.77 24.8929 110.111 24.675C109.447 24.4593 108.83 24.1476 108.275 23.7468L108.134 23.6531V26.7937L108.181 26.8171C108.65 27.0281 109.228 27.2156 109.916 27.3562C110.601 27.5085 111.228 27.5789 111.767 27.5789C113.443 27.5789 114.791 27.1804 115.775 26.4023C116.759 25.6148 117.263 24.5625 117.263 23.2804C117.263 22.3546 116.994 21.5578 116.461 20.9191C115.933 20.2792 115.019 19.6957 113.738 19.18C112.727 18.7699 112.074 18.43 111.793 18.1722C111.535 17.9191 111.414 17.5628 111.414 17.1128C111.414 16.7144 111.579 16.3933 111.912 16.1355C112.248 15.8718 112.716 15.7406 113.302 15.7406C113.847 15.7406 114.404 15.8226 114.966 15.9925C115.517 16.166 116.004 16.391 116.408 16.6675L116.545 16.7613V13.7613L116.498 13.7378C116.117 13.5738 115.623 13.4367 115.021 13.3277C114.424 13.214 113.881 13.1636 113.41 13.1636L113.397 13.1683ZM99.582 24.8941C98.3984 24.8941 97.4609 24.5027 96.8047 23.7222C96.1367 22.9488 95.8027 21.8355 95.8027 20.4175C95.8027 18.9644 96.1379 17.816 96.8035 17.0273C97.4598 16.2398 98.3902 15.839 99.5574 15.839C100.694 15.839 101.596 16.221 102.247 16.9757C102.894 17.7375 103.231 18.8695 103.231 20.3437C103.231 21.8343 102.915 22.9804 102.305 23.748C101.708 24.5097 100.794 24.8964 99.5867 24.8964L99.582 24.8941ZM99.7508 13.166C97.4773 13.166 95.6727 13.8269 94.3953 15.1371C93.1098 16.4496 92.4617 18.2601 92.4617 20.5277C92.4617 22.6839 93.0945 24.4113 94.3402 25.6722C95.5965 26.9378 97.3004 27.5941 99.4086 27.5941C101.612 27.5941 103.37 26.9144 104.659 25.5902C105.941 24.2613 106.592 22.4636 106.592 20.2523C106.592 18.0644 105.983 16.3183 104.787 15.0726C103.58 13.8128 101.886 13.1777 99.7484 13.1777L99.7508 13.166ZM87.5164 15.8824V13.4917H84.282V27.2378H87.5164V20.2066C87.5164 19.0113 87.7859 18.0269 88.3215 17.2828C88.8488 16.5421 89.552 16.1812 90.4074 16.1812C90.7004 16.1812 91.0285 16.2281 91.3895 16.3218C91.741 16.4156 91.9941 16.5093 92.1395 16.6265L92.2801 16.7203V13.4625L92.2285 13.439C91.9238 13.3031 91.502 13.2375 90.9629 13.2375C90.1543 13.2375 89.4277 13.5 88.8043 14.0109C88.2535 14.4656 87.8586 15.0843 87.5562 15.8578H87.4977L87.527 15.8812L87.5164 15.8824ZM78.4695 13.1636C76.9812 13.1636 75.657 13.4742 74.532 14.1011C73.3977 14.7339 72.5281 15.6246 71.9305 16.773C71.3445 17.9097 71.0398 19.2398 71.0398 20.7222C71.0398 22.023 71.3352 23.2113 71.907 24.2636C72.4859 25.3183 73.3016 26.1386 74.3328 26.7128C75.357 27.2789 76.5477 27.5683 77.8648 27.5683C79.4023 27.5683 80.7125 27.2636 81.7672 26.6542L81.8141 26.6308V23.6636L81.6734 23.7609C81.1965 24.1124 80.6656 24.3878 80.0914 24.5871C79.5195 24.7863 78.9992 24.8871 78.5445 24.8871C77.2719 24.8871 76.2547 24.4886 75.5141 23.7093C74.7641 22.9124 74.3891 21.8109 74.3891 20.4281C74.3891 19.0218 74.7875 17.8968 75.5562 17.0765C76.3297 16.2328 77.3469 15.8109 78.5914 15.8109C79.6461 15.8109 80.6855 16.1742 81.6652 16.8773L81.8059 16.971V13.8539L81.7672 13.8304C81.398 13.6195 80.8965 13.4554 80.2672 13.3218C79.6508 13.1929 79.0437 13.1296 78.4648 13.1296L78.4695 13.1636ZM68.8203 13.4578H65.5906V27.2156H68.825V13.4578H68.8203ZM67.2266 7.61011C66.6945 7.61011 66.2305 7.79058 65.8484 8.14917C65.4664 8.51011 65.2719 8.96245 65.2719 9.49683C65.2719 10.0242 65.4676 10.4695 65.8461 10.821C66.2211 11.1726 66.6898 11.346 67.2289 11.346C67.768 11.346 68.2367 11.1703 68.6176 10.8187C69.002 10.4671 69.1965 10.0218 69.1965 9.49448C69.1965 8.97886 69.009 8.53355 68.634 8.15855C68.259 7.80698 67.7902 7.61948 67.2277 7.61948L67.2266 7.61011ZM59.1535 12.4593V27.2249H62.4582V8.05425H57.8879L52.0953 22.3019L46.4586 8.0519H41.7078V27.2378H44.8133V12.4781H44.9188L50.8719 27.2414H53.2098L59.0691 12.4792H59.1805L59.1629 12.4722L59.1535 12.4593ZM16.884 18.4242H32.0949V33.648H16.8605L16.8816 18.4347L16.884 18.4242ZM0.0828125 18.4335H15.2914V33.648H0.078125L0.0828125 18.4347V18.4335ZM16.8852 1.63237H32.0961V16.8433H16.8758L16.8852 1.62769V1.63237ZM0.0828125 1.63003H15.2914V16.8433H0.078125L0.0828125 1.62769V1.63003Z" fill="currentColor"/></g><defs><clipPath id="clip0_3753_27919"><rect width="150" height="32.8125" fill="white" transform="translate(0.0820312 0.835449)"/></clipPath></defs>
                            </svg>
                        </.page_link>

                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 124 38" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path d="M50.8299 17.3952C54.7246 18.342 56.3124 19.8121 56.3124 22.4701C56.3124 25.615 53.9096 27.6473 50.1907 27.6473C47.5621 27.6473 45.1252 26.7135 43.1446 24.9452C43.104 24.9089 43.0791 24.8582 43.0754 24.8038C43.0716 24.7494 43.0893 24.6957 43.1246 24.6542L44.8747 22.5724C44.8926 22.5512 44.9145 22.5336 44.9392 22.5209C44.9639 22.5082 44.9909 22.5005 45.0185 22.4983C45.0462 22.4961 45.0741 22.4995 45.1005 22.5082C45.1269 22.5169 45.1513 22.5307 45.1723 22.5489C46.8747 24.0226 48.3966 24.6506 50.2619 24.6506C51.9419 24.6506 52.9857 23.9232 52.9857 22.7541C52.9857 21.6986 52.4694 21.1088 49.4104 20.4043C45.8174 19.5351 43.7374 18.4108 43.7374 15.2323C43.7374 12.2686 46.1484 10.1986 49.5991 10.1986C51.9455 10.1986 53.9548 10.8937 55.7384 12.3244C55.8243 12.3938 55.8419 12.5185 55.7778 12.609L54.2165 14.8084C54.2002 14.831 54.1796 14.8501 54.1558 14.8647C54.1321 14.8793 54.1057 14.8891 54.0781 14.8935C54.0506 14.8978 54.0224 14.8967 53.9953 14.8902C53.9682 14.8837 53.9427 14.8718 53.9202 14.8554C52.4218 13.7381 50.9928 13.1959 49.5509 13.1959C48.0643 13.1959 47.0646 13.9104 47.0646 14.9718C47.0646 16.095 47.635 16.6302 50.8305 17.3934L50.8299 17.3952ZM64.7256 14.2432C63.1144 14.2432 61.7924 14.8783 60.7016 16.1779V14.7137C60.7016 14.6582 60.6795 14.6049 60.6403 14.5657C60.601 14.5264 60.5478 14.5043 60.4922 14.5043H57.6308C57.5752 14.5043 57.522 14.5264 57.4827 14.5657C57.4435 14.6049 57.4214 14.6582 57.4214 14.7137V30.9851C57.4214 31.0998 57.5155 31.1939 57.6308 31.1939H60.4928C60.6087 31.1939 60.7028 31.0998 60.7028 30.9846V25.8479C61.793 27.0711 63.1156 27.6697 64.7274 27.6697C67.7235 27.6697 70.755 25.3645 70.755 20.9565C70.755 16.5484 67.7218 14.2432 64.7256 14.2432ZM67.4248 20.9571C67.4248 23.2011 66.0429 24.7676 64.0635 24.7676C62.1053 24.7676 60.6293 23.1299 60.6293 20.9571C60.6293 18.7842 62.1053 17.1465 64.0635 17.1465C66.0111 17.1465 67.4254 18.7489 67.4254 20.9571H67.4248ZM78.5255 14.2432C74.6679 14.2432 71.6465 17.2129 71.6465 21.0059C71.6465 24.7565 74.6467 27.695 78.4773 27.695C82.3485 27.695 85.3793 24.7347 85.3793 20.9571C85.3793 17.1923 82.3684 14.2427 78.5249 14.2427L78.5255 14.2432ZM78.5249 24.7906C76.4726 24.7906 74.926 23.1423 74.926 20.9565C74.926 18.7618 76.4197 17.1694 78.4779 17.1694C80.542 17.1694 82.1003 18.8177 82.1003 21.0047C82.1003 23.1981 80.5961 24.79 78.5249 24.79V24.7906ZM93.6168 14.5043C93.7326 14.5043 93.8261 14.5984 93.8261 14.7137V17.1735C93.8262 17.201 93.8208 17.2282 93.8104 17.2536C93.7999 17.279 93.7846 17.3021 93.7652 17.3215C93.7458 17.341 93.7227 17.3564 93.6974 17.3669C93.672 17.3774 93.6448 17.3829 93.6173 17.3829H90.4683V23.2993C90.4683 24.2343 90.8788 24.6506 91.7973 24.6506C92.3818 24.6538 92.9582 24.5145 93.4768 24.2449C93.5089 24.229 93.5444 24.2215 93.5802 24.2232C93.6159 24.2249 93.6507 24.2356 93.6811 24.2545C93.7115 24.2733 93.7366 24.2996 93.7541 24.3308C93.7715 24.3621 93.7807 24.3973 93.7808 24.433V26.7747C93.7808 26.8494 93.7397 26.9199 93.675 26.957C92.8723 27.4115 92.0208 27.6232 90.9934 27.6232C88.4689 27.6232 87.1887 26.3195 87.1887 23.7468V17.3834H85.8127C85.7853 17.3834 85.7581 17.3779 85.7328 17.3673C85.7075 17.3568 85.6846 17.3413 85.6652 17.3219C85.6459 17.3024 85.6306 17.2794 85.6202 17.254C85.6098 17.2287 85.6044 17.2015 85.6045 17.1741V14.7137C85.6045 14.5984 85.6974 14.5043 85.8127 14.5043H87.1887V11.2841C87.1887 11.1689 87.2828 11.0748 87.3993 11.0748H90.2607C90.3766 11.0748 90.4701 11.1689 90.4701 11.2841V14.5043H93.6191H93.6168ZM109.48 14.5167C109.566 14.5167 109.644 14.5696 109.675 14.6519L113.018 23.3751L116.07 14.6566C116.085 14.6155 116.112 14.5798 116.147 14.5545C116.183 14.5293 116.225 14.5156 116.269 14.5155H119.248C119.282 14.5155 119.316 14.5238 119.346 14.5398C119.376 14.5558 119.402 14.5789 119.421 14.6072C119.441 14.6354 119.452 14.668 119.456 14.7019C119.46 14.7359 119.455 14.7702 119.442 14.8019L114.477 27.6332C113.448 30.2812 112.279 31.2656 110.166 31.2656C109.036 31.2656 108.122 31.0316 107.108 30.4835C107.062 30.4584 107.027 30.4163 107.01 30.366C106.993 30.3157 106.997 30.261 107.019 30.213L107.989 28.0843C108.001 28.058 108.018 28.0345 108.04 28.0151C108.061 27.9957 108.086 27.9808 108.113 27.9714C108.14 27.9626 108.169 27.9595 108.198 27.9622C108.227 27.9649 108.255 27.9734 108.28 27.9872C108.823 28.2842 109.354 28.4342 109.859 28.4342C110.482 28.4342 110.939 28.2295 111.404 27.1981L107.311 17.3834H104.638V27.201C104.638 27.3169 104.544 27.4109 104.429 27.4109H101.567C101.539 27.4109 101.512 27.4055 101.486 27.395C101.461 27.3844 101.438 27.3689 101.418 27.3494C101.399 27.3299 101.384 27.3068 101.373 27.2813C101.363 27.2558 101.357 27.2286 101.357 27.201V17.3834H99.9824C99.9269 17.383 99.8738 17.3607 99.8345 17.3215C99.7952 17.2822 99.773 17.229 99.7725 17.1735V14.7019C99.7725 14.5861 99.8666 14.492 99.9818 14.492H101.357V13.8863C101.357 11.0719 102.754 9.58291 105.398 9.58291C106.484 9.58291 107.209 9.75638 107.777 9.92398C107.866 9.95162 107.925 10.0334 107.925 10.1251V12.5361C107.926 12.5695 107.918 12.6024 107.903 12.6322C107.888 12.662 107.866 12.6878 107.839 12.7074C107.813 12.727 107.781 12.7398 107.748 12.7448C107.715 12.7498 107.682 12.7468 107.65 12.7361C107.113 12.5573 106.634 12.4385 106.038 12.4385C105.038 12.4385 104.591 12.9578 104.591 14.1215V14.5167H109.479H109.48ZM98.2289 14.5043C98.3441 14.5043 98.4382 14.5984 98.4382 14.7137V27.2004C98.4382 27.3157 98.3441 27.4098 98.2283 27.4098H95.3662C95.3106 27.4098 95.2573 27.3877 95.218 27.3485C95.1786 27.3092 95.1564 27.256 95.1563 27.2004V14.7137C95.1563 14.5984 95.2504 14.5043 95.3656 14.5043H98.2277H98.2289ZM96.8122 8.81903C97.3565 8.81903 97.8786 9.03525 98.2634 9.42013C98.6483 9.80502 98.8645 10.327 98.8645 10.8713C98.8645 11.4156 98.6483 11.9377 98.2634 12.3225C97.8786 12.7074 97.3565 12.9236 96.8122 12.9236C96.2679 12.9236 95.7459 12.7074 95.361 12.3225C94.9762 11.9377 94.7599 11.4156 94.7599 10.8713C94.7599 10.327 94.9762 9.80502 95.361 9.42013C95.7459 9.03525 96.2679 8.81903 96.8122 8.81903ZM121.886 18.5184C121.621 18.5194 121.359 18.468 121.114 18.3671C120.869 18.2663 120.646 18.118 120.459 17.9307C120.272 17.7435 120.124 17.5211 120.023 17.2763C119.922 17.0314 119.871 16.7691 119.872 16.5043C119.872 16.2385 119.924 15.9752 120.026 15.7296C120.127 15.484 120.277 15.2608 120.465 15.0729C120.653 14.8849 120.876 14.7358 121.122 14.6341C121.367 14.5324 121.63 14.4801 121.896 14.4802C122.161 14.4791 122.423 14.5303 122.668 14.631C122.913 14.7318 123.135 14.88 123.323 15.0671C123.51 15.2543 123.658 15.4766 123.759 15.7214C123.86 15.9661 123.911 16.2284 123.91 16.4931C123.91 16.7591 123.858 17.0225 123.756 17.2682C123.655 17.514 123.506 17.7373 123.318 17.9254C123.13 18.1135 122.906 18.2627 122.661 18.3646C122.415 18.4664 122.152 18.5189 121.886 18.519V18.5184ZM121.896 14.6808C120.865 14.6808 120.084 15.5011 120.084 16.5049C120.084 17.5087 120.859 18.3179 121.886 18.3179C122.917 18.3179 123.699 17.4981 123.699 16.4937C123.699 15.4899 122.922 14.6808 121.896 14.6808ZM122.343 16.7007L122.912 17.4981H122.432L121.92 16.7666H121.479V17.4981H121.077V15.3841H122.02C122.51 15.3841 122.834 15.6358 122.834 16.0586C122.834 16.4055 122.634 16.6172 122.343 16.6995L122.343 16.7007ZM122.002 15.7469H121.478V16.4149H122.002C122.264 16.4149 122.419 16.2867 122.419 16.0797C122.419 15.8622 122.264 15.7463 122.002 15.7463V15.7469ZM18.9768 0.305176C8.75288 0.305176 0.464844 8.70847 0.464844 18.933C0.464256 28.54 7.78083 36.2953 17.1462 37.4714H20.8074C30.1728 36.2953 37.4893 28.54 37.4893 18.9324C37.4893 8.70847 29.2007 0.305176 18.9774 0.305176H18.9768ZM27.4665 27.0064C27.3877 27.1359 27.284 27.2486 27.1616 27.3379C27.0391 27.4273 26.9002 27.4917 26.7528 27.5273C26.6054 27.5629 26.4525 27.5691 26.3027 27.5455C26.1529 27.5219 26.0093 27.469 25.88 27.3898C21.5325 24.733 16.0612 24.1331 9.61732 25.605C9.46966 25.639 9.31676 25.6435 9.16736 25.6183C9.01796 25.5931 8.87499 25.5387 8.74664 25.4582C8.61829 25.3777 8.50707 25.2726 8.41934 25.1491C8.33162 25.0256 8.26911 24.886 8.23539 24.7382C8.20146 24.5905 8.19701 24.4375 8.22229 24.2881C8.24756 24.1386 8.30207 23.9956 8.3827 23.8672C8.46332 23.7389 8.56848 23.6277 8.69214 23.54C8.8158 23.4523 8.95554 23.3899 9.10336 23.3563C16.1553 21.745 22.204 22.439 27.0837 25.4204C27.3446 25.5803 27.5314 25.8371 27.603 26.1346C27.6747 26.4321 27.6254 26.7458 27.4659 27.007L27.4665 27.0064ZM29.7317 21.9656C29.5314 22.2916 29.2099 22.5248 28.8377 22.6139C28.4656 22.703 28.0733 22.6407 27.747 22.4407C22.7721 19.3828 15.1862 18.4966 9.29977 20.2837C8.93342 20.3943 8.53819 20.3552 8.2006 20.175C7.86301 19.9948 7.61058 19.6882 7.49856 19.3223C7.26922 18.5578 7.6985 17.7539 8.46121 17.5228C15.1856 15.4823 23.5436 16.4702 29.2577 19.9809C29.5837 20.1813 29.8168 20.5029 29.9058 20.875C29.9948 21.2472 29.9324 21.6394 29.7323 21.9656H29.7317ZM29.9269 16.7166C23.9594 13.173 14.1165 12.8472 8.42004 14.5761C7.98054 14.7093 7.50613 14.6624 7.10118 14.4458C6.69622 14.2292 6.3939 13.8606 6.26071 13.4211C6.12752 12.9816 6.17437 12.5072 6.39096 12.1023C6.60756 11.6973 6.97615 11.395 7.41565 11.2618C13.9548 9.27712 24.8256 9.66053 31.6952 13.7375C31.8908 13.8535 32.0617 14.0069 32.198 14.1889C32.3343 14.371 32.4334 14.5781 32.4897 14.7984C32.5459 15.0188 32.5582 15.248 32.5258 15.4731C32.4934 15.6982 32.417 15.9148 32.3009 16.1103C32.185 16.3061 32.0316 16.477 31.8495 16.6134C31.6674 16.7498 31.4603 16.849 31.2398 16.9053C31.0194 16.9615 30.79 16.9738 30.5648 16.9413C30.3397 16.9088 30.1231 16.8323 29.9275 16.716L29.9269 16.7166Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 137 37" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path d="M53.3228 13.9636C51.5883 13.9636 50.7303 15.3285 50.3366 16.209C50.1166 16.7006 50.0551 17.0893 49.8767 17.0893C49.6253 17.0893 49.8054 16.7514 49.5997 16.0022C49.329 15.0165 48.5133 13.9636 46.78 13.9636C44.9577 13.9636 44.1775 15.5032 43.8075 16.3493C43.5545 16.9276 43.5542 17.0893 43.3597 17.0893C43.0778 17.0893 43.3113 16.6298 43.4381 16.0897C43.688 15.0263 43.498 14.2136 43.498 14.2136H40.6094V25.0758H44.5523C44.5523 25.0758 44.5523 20.5363 44.5523 19.6714C44.5523 18.6054 44.9982 17.2528 45.7625 17.2528C46.6456 17.2528 46.8224 17.931 46.8224 19.1869C46.8224 20.3255 46.8224 25.0781 46.8224 25.0781H50.7812C50.7812 25.0781 50.7812 20.511 50.7812 19.6714C50.7812 18.7226 51.1684 17.2528 51.9972 17.2528C52.8926 17.2528 53.0511 18.2056 53.0511 19.1869C53.0511 20.1682 53.0511 25.0758 53.0511 25.0758H56.9387C56.9387 25.0758 56.9387 20.7719 56.9387 18.6882C56.9387 15.8535 55.9395 13.9636 53.3228 13.9636Z" fill="currentColor"/>
                                <path d="M120.249 13.9636C118.514 13.9636 117.656 15.3285 117.262 16.209C117.042 16.7006 116.981 17.0893 116.802 17.0893C116.551 17.0893 116.719 16.6601 116.526 16.0022C116.237 15.0217 115.518 13.9636 113.706 13.9636C111.884 13.9636 111.103 15.5032 110.733 16.3493C110.48 16.9276 110.48 17.0893 110.286 17.0893C110.004 17.0893 110.237 16.6298 110.364 16.0897C110.614 15.0263 110.424 14.2136 110.424 14.2136H107.535V25.0758H111.478C111.478 25.0758 111.478 20.5363 111.478 19.6714C111.478 18.6054 111.924 17.2528 112.688 17.2528C113.571 17.2528 113.748 17.931 113.748 19.1869C113.748 20.3255 113.748 25.0781 113.748 25.0781H117.707C117.707 25.0781 117.707 20.511 117.707 19.6714C117.707 18.7226 118.094 17.2528 118.923 17.2528C119.819 17.2528 119.977 18.2056 119.977 19.1869C119.977 20.1682 119.977 25.0758 119.977 25.0758H123.865C123.865 25.0758 123.865 20.7719 123.865 18.6882C123.865 15.8535 122.865 13.9636 120.249 13.9636Z" fill="currentColor"/>
                                <path d="M62.7138 22.5371C61.7709 22.7549 61.2821 22.4645 61.2821 21.8395C61.2821 20.9834 62.1676 20.6406 63.4315 20.6406C63.9887 20.6406 64.5126 20.6888 64.5126 20.6888C64.5126 21.0552 63.7172 22.3056 62.7138 22.5371ZM63.6737 13.9661C60.6534 13.9661 58.4862 15.0765 58.4862 15.0765V18.3405C58.4862 18.3405 60.8795 16.9645 62.821 16.9645C64.3707 16.9645 64.5611 17.8003 64.4905 18.494C64.4905 18.494 64.0437 18.3757 62.6797 18.3757C59.4661 18.3757 57.8438 19.8362 57.8438 22.1782C57.8438 24.3997 59.667 25.3284 61.2031 25.3284C63.4446 25.3284 64.4299 23.8221 64.7327 23.1075C64.9428 22.6117 64.9811 22.2776 65.1699 22.2776C65.3849 22.2776 65.3125 22.5172 65.3021 23.0107C65.2839 23.8748 65.3246 24.528 65.4616 25.0782H68.4334V19.7326C68.4334 16.395 67.2525 13.9661 63.6737 13.9661Z" fill="currentColor"/>
                                <path d="M74.9258 25.0783H78.8688V10.9255H74.9258V25.0783Z" fill="currentColor"/>
                                <path d="M83.2111 19.6471C83.2111 18.6705 84.1184 17.7819 85.7842 17.7819C87.5992 17.7819 89.059 18.6558 89.3864 18.8542V15.0765C89.3864 15.0765 88.2331 13.9661 85.3984 13.9661C82.4103 13.9661 79.9219 15.7146 79.9219 19.4781C79.9219 23.2415 82.1801 25.3284 85.3904 25.3284C87.898 25.3284 89.3928 23.9506 89.3928 23.9506V20.3624C88.9199 20.6271 87.6021 21.5415 85.8023 21.5415C83.8964 21.5415 83.2111 20.6648 83.2111 19.6471Z" fill="currentColor"/>
                                <path d="M97.373 13.9662C95.0905 13.9662 94.2223 16.1293 94.047 16.5049C93.8716 16.8804 93.785 17.0964 93.6415 17.0918C93.3923 17.0837 93.566 16.6308 93.6631 16.3375C93.8467 15.7834 94.2357 14.3297 94.2357 12.543C94.2357 11.3311 94.0718 10.9255 94.0718 10.9255H90.668V25.0783H94.611C94.611 25.0783 94.611 20.5543 94.611 19.6741C94.611 18.7937 94.9623 17.2554 95.9556 17.2554C96.7784 17.2554 97.036 17.8651 97.036 19.0927C97.036 20.3201 97.036 25.0783 97.036 25.0783H100.979C100.979 25.0783 100.979 21.7679 100.979 19.3289C100.979 16.5406 100.517 13.9662 97.373 13.9662Z" fill="currentColor"/>
                                <path d="M102.258 14.2285V25.0782H106.201V14.2285C106.201 14.2285 105.538 14.6162 104.233 14.6162C102.929 14.6162 102.258 14.2285 102.258 14.2285Z" fill="currentColor"/>
                                <path d="M104.218 10.8157C102.885 10.8157 101.805 11.521 101.805 12.391C101.805 13.2609 102.885 13.9662 104.218 13.9662C105.551 13.9662 106.632 13.2609 106.632 12.391C106.632 11.521 105.551 10.8157 104.218 10.8157Z" fill="currentColor"/>
                                <path d="M69.707 14.2285V25.0782H73.6499V14.2285C73.6499 14.2285 72.9872 14.6162 71.6825 14.6162C70.3779 14.6162 69.707 14.2285 69.707 14.2285Z" fill="currentColor"/>
                                <path d="M71.6674 10.8157C70.3345 10.8157 69.2539 11.521 69.2539 12.391C69.2539 13.2609 70.3345 13.9662 71.6674 13.9662C73.0005 13.9662 74.0811 13.2609 74.0811 12.391C74.0811 11.521 73.0005 10.8157 71.6674 10.8157Z" fill="currentColor"/>
                                <path d="M130.616 22.744C129.712 22.744 129.047 21.5972 129.047 19.9993C129.047 18.4475 129.73 17.2552 130.585 17.2552C131.682 17.2552 132.15 18.2614 132.15 19.9993C132.15 21.8071 131.719 22.744 130.616 22.744ZM131.699 13.9636C129.672 13.9636 128.743 15.4835 128.339 16.3493C128.072 16.9214 128.086 17.0893 127.891 17.0893C127.609 17.0893 127.843 16.6298 127.97 16.0897C128.219 15.0263 128.029 14.2136 128.029 14.2136H125.141V28.0756H129.084C129.084 28.0756 129.084 25.8073 129.084 23.6807C129.55 24.4722 130.414 25.3179 131.747 25.3179C134.598 25.3179 136.033 22.9056 136.033 19.6462C136.033 15.952 134.315 13.9636 131.699 13.9636Z" fill="currentColor"/>
                                <path d="M26.682 17.2446C26.9471 17.213 27.2012 17.2115 27.4346 17.2446C27.5697 16.9348 27.593 16.4007 27.4714 15.819C27.2907 14.9545 27.0463 14.4313 26.5411 14.5127C26.036 14.5941 26.0173 15.2205 26.1979 16.0851C26.2995 16.5714 26.4804 16.987 26.682 17.2446Z" fill="currentColor"/>
                                <path d="M22.3442 17.9286C22.7056 18.0873 22.9278 18.1924 23.0147 18.1005C23.0706 18.0433 23.054 17.934 22.9677 17.7929C22.7893 17.5017 22.4222 17.2064 22.033 17.0405C21.2368 16.6978 20.2872 16.8118 19.5546 17.3381C19.3129 17.5153 19.0836 17.7608 19.1164 17.9098C19.1271 17.958 19.1633 17.9943 19.2481 18.0062C19.4476 18.029 20.1443 17.6767 20.9468 17.6276C21.5133 17.5929 21.9827 17.7701 22.3442 17.9286Z" fill="currentColor"/>
                                <path d="M21.6149 18.3436C21.1441 18.4179 20.8844 18.5732 20.7177 18.7175C20.5755 18.8417 20.4875 18.9792 20.4883 19.0759C20.4886 19.1219 20.5086 19.1484 20.5243 19.1618C20.5458 19.1806 20.5712 19.1911 20.6017 19.1911C20.7081 19.1911 20.9462 19.0955 20.9462 19.0955C21.6014 18.861 22.0335 18.8895 22.4618 18.9383C22.6985 18.9648 22.8103 18.9795 22.8622 18.8984C22.8776 18.8751 22.8962 18.8247 22.8488 18.7479C22.7385 18.569 22.2632 18.2666 21.6149 18.3436" fill="currentColor"/>
                                <path d="M25.2163 19.8666C25.5358 20.0237 25.8877 19.962 26.0024 19.7289C26.1169 19.4959 25.9506 19.1796 25.6309 19.0224C25.3113 18.8655 24.9594 18.927 24.8448 19.1601C24.7303 19.3933 24.8965 19.7094 25.2163 19.8666Z" fill="currentColor"/>
                                <path d="M27.2703 18.0709C27.0106 18.0664 26.7953 18.3516 26.7892 18.7076C26.7831 19.0638 26.9888 19.356 27.2485 19.3604C27.5081 19.3649 27.7236 19.0797 27.7295 18.7237C27.7356 18.3674 27.5299 18.0752 27.2703 18.0709Z" fill="currentColor"/>
                                <path d="M9.83004 24.4919C9.76544 24.411 9.65932 24.4356 9.55655 24.4596C9.48477 24.4764 9.40345 24.4952 9.31429 24.4937C9.1233 24.4899 8.96157 24.4085 8.87074 24.2689C8.75244 24.0872 8.75928 23.8163 8.88991 23.5064C8.90748 23.4644 8.92824 23.418 8.95084 23.3674C9.15903 22.9001 9.50765 22.118 9.11629 21.3728C8.82172 20.812 8.34133 20.4626 7.76373 20.3893C7.20923 20.319 6.63835 20.5246 6.27421 20.9263C5.69973 21.5601 5.60995 22.4226 5.72105 22.7274C5.76179 22.8389 5.82544 22.8698 5.87174 22.8761C5.96945 22.8892 6.11398 22.8181 6.20453 22.5745C6.211 22.557 6.21962 22.5298 6.23042 22.4953C6.27082 22.3666 6.34593 22.1268 6.46897 21.9346C6.61733 21.7028 6.8484 21.5432 7.11962 21.4851C7.39594 21.4259 7.67834 21.4787 7.91474 21.6335C8.31723 21.8967 8.47219 22.3898 8.30037 22.8604C8.21157 23.1037 8.06727 23.569 8.09913 23.9514C8.16344 24.7251 8.63936 25.0359 9.06699 25.069C9.48275 25.0845 9.77331 24.8513 9.84682 24.6806C9.89021 24.5797 9.85359 24.5183 9.83005 24.4919" fill="currentColor"/>
                                <path d="M13.781 10.2801C15.137 8.71317 16.8063 7.35092 18.3016 6.58601C18.3533 6.55944 18.4082 6.61569 18.3802 6.66639C18.2614 6.88141 18.0329 7.34188 17.9604 7.69111C17.9491 7.74554 18.0083 7.78647 18.0542 7.75518C18.9845 7.12106 20.6029 6.44157 22.0223 6.35422C22.0833 6.35044 22.1128 6.42867 22.0643 6.46589C21.8484 6.63154 21.6123 6.86065 21.4398 7.09244C21.4104 7.13187 21.4381 7.18868 21.4873 7.18898C22.484 7.19608 23.8891 7.54489 24.805 8.05859C24.8669 8.09327 24.8227 8.21326 24.7535 8.19739C23.3678 7.87989 21.0996 7.63891 18.7435 8.21358C16.6401 8.72668 15.0346 9.51873 13.8634 10.3705C13.8042 10.4137 13.7331 10.3355 13.781 10.2801L13.781 10.2801ZM20.5345 25.4617C20.5346 25.462 20.5348 25.4626 20.5349 25.4626C20.5352 25.463 20.5353 25.4638 20.5357 25.4642C20.5353 25.4634 20.5349 25.4626 20.5345 25.4617ZM26.1264 26.1218C26.1666 26.1049 26.1944 26.0591 26.1896 26.0136C26.184 25.9575 26.134 25.9167 26.0779 25.9225C26.0779 25.9225 23.1841 26.3507 20.4504 25.3501C20.7482 24.3823 21.5399 24.7317 22.7367 24.8283C24.8938 24.9569 26.827 24.6418 28.2558 24.2316C29.494 23.8765 31.12 23.1759 32.3831 22.1789C32.8091 23.1148 32.9595 24.1446 32.9595 24.1446C32.9595 24.1446 33.2893 24.0857 33.5648 24.2552C33.8252 24.4155 34.0162 24.7486 33.8857 25.6099C33.6201 27.219 32.9362 28.525 31.7868 29.7265C31.087 30.4796 30.2375 31.1345 29.2656 31.6107C28.7494 31.8818 28.1998 32.1164 27.6192 32.3059C23.2857 33.7212 18.85 32.1653 17.4201 28.8239C17.3061 28.5727 17.2095 28.3098 17.1335 28.0347C16.5241 25.8328 17.0414 23.1911 18.6584 21.5282C18.6585 21.528 18.6582 21.5273 18.6584 21.5273C18.758 21.4215 18.8598 21.2967 18.8598 21.1398C18.8598 21.0086 18.7764 20.8701 18.7041 20.7719C18.1383 19.9514 16.1787 18.5531 16.572 15.8472C16.8545 13.9031 18.5546 12.5341 20.1397 12.6152C20.2736 12.6222 20.4078 12.6303 20.5415 12.6382C21.2284 12.679 21.8276 12.7671 22.3931 12.7906C23.3395 12.8316 24.1906 12.6939 25.1986 11.8541C25.5386 11.5707 25.8112 11.3252 26.2725 11.247C26.321 11.2387 26.4416 11.1954 26.6827 11.2068C26.9287 11.2199 27.163 11.2875 27.3735 11.4276C28.1817 11.9654 28.2962 13.2677 28.3381 14.2205C28.362 14.7643 28.4279 16.0801 28.4502 16.4579C28.5017 17.3215 28.7287 17.4433 29.188 17.5945C29.4463 17.6797 29.6861 17.743 30.0395 17.8422C31.1092 18.1425 31.7435 18.4472 32.1431 18.8386C32.3816 19.0831 32.4925 19.3431 32.5268 19.5909C32.6528 20.5111 31.8123 21.6478 29.5872 22.6807C27.1549 23.8095 24.2041 24.0954 22.1653 23.8684C22.009 23.851 21.4529 23.788 21.451 23.7877C19.8201 23.5681 18.8899 25.6757 19.8686 27.1196C20.4995 28.0501 22.2176 28.6558 23.9367 28.6561C27.8783 28.6565 30.9078 26.9734 32.0347 25.5198C32.0685 25.4763 32.0718 25.4716 32.1249 25.3912C32.1803 25.3077 32.1347 25.2616 32.0656 25.3089C31.1448 25.9389 27.0552 28.4401 22.6808 27.6876C22.6808 27.6876 22.1493 27.6002 21.6641 27.4115C21.2785 27.2615 20.4715 26.8902 20.3734 26.0623C23.9036 27.154 26.1264 26.1219 26.1264 26.1219V26.1218ZM6.73637 17.7322C5.50864 17.971 4.42653 18.6668 3.76488 19.6279C3.36935 19.2981 2.63255 18.6595 2.50245 18.4107C1.44601 16.4049 3.65533 12.5048 5.19871 10.3023C9.01295 4.85925 14.9868 0.739281 17.7523 1.48684C18.2019 1.61408 19.6908 3.3404 19.6908 3.3404C19.6908 3.3404 16.9266 4.87423 14.363 7.01221C10.9088 9.6719 8.2995 13.5375 6.73637 17.7322ZM8.79942 26.937C8.61359 26.9687 8.42406 26.9814 8.23288 26.9767C6.38562 26.9272 4.39022 25.2641 4.19193 23.2919C3.97278 21.1119 5.08663 19.4342 7.05879 19.0364C7.29457 18.9889 7.57951 18.9615 7.88676 18.9775C8.99175 19.038 10.6201 19.8864 10.9921 22.2937C11.3216 24.4256 10.7983 26.5961 8.79942 26.937V26.937ZM33.8233 23.0768C33.8075 23.0209 33.7044 22.6441 33.5628 22.1901C33.4211 21.7358 33.2745 21.4162 33.2745 21.4162C33.8426 20.5656 33.8527 19.805 33.7772 19.374C33.6965 18.84 33.4742 18.3849 33.0261 17.9145C32.5779 17.4441 31.6614 16.9623 30.3733 16.6006C30.2261 16.5592 29.7403 16.4259 29.6976 16.413C29.6942 16.3851 29.662 14.8197 29.6328 14.1478C29.6114 13.662 29.5697 12.9036 29.3344 12.1566C29.054 11.1455 28.5653 10.2608 27.9555 9.69474C29.6385 7.95018 30.6892 6.02826 30.6867 4.37951C30.6818 1.20879 26.7878 0.24946 21.9891 2.23648C21.9841 2.23854 20.9797 2.66446 20.9724 2.66802C20.9678 2.66372 19.1343 0.864594 19.1067 0.84057C13.6355 -3.9316 -3.4707 15.0823 1.99847 19.7003L3.19371 20.7129C2.88368 21.516 2.76185 22.4362 2.86137 23.4258C2.9891 24.6967 3.64467 25.915 4.70726 26.8562C5.71596 27.75 7.04217 28.3156 8.32916 28.3145C10.4574 33.2191 15.3203 36.2279 21.0221 36.3972C27.1383 36.5789 32.2724 33.709 34.4238 28.5537C34.5645 28.1919 35.1617 26.5617 35.1617 25.1226C35.1617 23.6763 34.344 23.0768 33.8233 23.0768Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-6 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 124 21" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M16.813 0.069519L12.5605 11.1781L8.28275 0.069519H0.96875V20.2025H6.23233V6.89245L11.4008 20.2025H13.7233L18.8634 6.89245V20.2025H24.127V0.069519H16.813Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M34.8015 16.461V15.1601C34.3138 14.4663 33.2105 14.1334 32.1756 14.1334C30.9504 14.1334 29.8174 14.679 29.8174 15.8245C29.8174 16.9699 30.9504 17.5155 32.1756 17.5155C33.2105 17.5155 34.3138 17.1533 34.8015 16.4595V16.461ZM34.8015 20.201V18.7519C33.8841 19.8358 32.1117 20.5633 30.213 20.5633C27.9484 20.5633 25.1367 19.0218 25.1367 15.7614C25.1367 12.2326 27.9469 11.0578 30.213 11.0578C32.1756 11.0578 33.9183 11.6885 34.8015 12.7767V11.3277C34.8015 10.0605 33.7042 9.18487 31.8039 9.18487C30.3349 9.18487 28.8658 9.75687 27.6748 10.7542L25.9322 7.52314C27.831 5.92447 30.3691 5.26007 32.6291 5.26007C36.1783 5.26007 39.5179 6.561 39.5179 11.0871V20.2025H34.8015V20.201Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M40.1562 18.3002L42.1145 14.9826C43.2178 15.9447 45.57 16.9421 47.3186 16.9421C48.7237 16.9421 49.3051 16.5461 49.3051 15.9154C49.3051 14.1055 40.7094 15.9741 40.7094 10.0605C40.7094 7.4938 42.9739 5.26007 47.0391 5.26007C49.5489 5.26007 51.6276 6.04474 53.22 7.1902L51.4194 10.4858C50.5303 9.6366 48.8471 8.88127 47.0747 8.88127C45.9715 8.88127 45.2384 9.30514 45.2384 9.8786C45.2384 11.4773 53.7999 9.81994 53.7999 15.7966C53.7999 18.5686 51.3257 20.5633 47.103 20.5633C44.4429 20.5633 41.7205 19.6862 40.1562 18.3002Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M64.7231 20.2025V11.7149C64.7231 9.94019 63.7759 9.36672 62.2712 9.36672C60.8958 9.36672 59.9784 10.1177 59.4313 10.7821V20.201H54.7148V0.069519H59.4313V7.40285C60.3145 6.37619 62.063 5.26152 64.5372 5.26152C67.9065 5.26152 69.4335 7.13299 69.4335 9.81992V20.2025H64.7231Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M80.0535 16.461V15.1601C79.5643 14.4663 78.4626 14.1334 77.4217 14.1334C76.1965 14.1334 75.0635 14.679 75.0635 15.8245C75.0635 16.9699 76.1965 17.5155 77.4217 17.5155C78.4626 17.5155 79.5643 17.1533 80.0535 16.4595V16.461ZM80.0535 20.201V18.7519C79.1346 19.8358 77.3578 20.5633 75.465 20.5633C73.199 20.5633 70.3828 19.0218 70.3828 15.7614C70.3828 12.2326 73.199 11.0578 75.465 11.0578C77.4217 11.0578 79.1644 11.6885 80.0535 12.7767V11.3277C80.0535 10.0605 78.9488 9.18487 77.056 9.18487C75.5869 9.18487 74.1164 9.75687 72.9209 10.7542L71.1783 7.52314C73.0771 5.92447 75.6152 5.26007 77.8812 5.26007C81.4289 5.26007 84.7625 6.561 84.7625 11.0871V20.2025H80.0535V20.201Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M93.8157 16.461C95.6802 16.461 97.0913 15.097 97.0913 12.897C97.0913 10.7263 95.6802 9.36232 93.8157 9.36232C92.8046 9.36232 91.5854 9.90645 90.9995 10.6911V15.1601C91.5854 15.9447 92.8061 16.461 93.8157 16.461ZM86.2891 20.201V0.069519H90.9995V7.34419C92.0485 6.01247 93.6688 5.2418 95.3784 5.26152C99.0778 5.26152 101.895 8.13032 101.895 12.897C101.895 17.847 99.0198 20.5633 95.3784 20.5633C93.7235 20.5633 92.2247 19.8989 90.9995 18.5114V20.2025H86.2891V20.201Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M102.844 0.069519H107.554V20.2025H102.844V0.069519Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M116.336 9.00154C114.284 9.00154 113.49 10.2101 113.303 11.2646H119.396C119.27 10.2379 118.508 9.00154 116.336 9.00154ZM108.5 12.897C108.5 8.67447 111.712 5.26007 116.336 5.26007C120.709 5.26007 123.892 8.42807 123.892 13.3781V14.4385H113.368C113.704 15.7335 114.929 16.8218 117.067 16.8218C118.108 16.8218 119.821 16.3686 120.681 15.5839L122.725 18.6317C121.26 19.9267 118.81 20.5633 116.55 20.5633C111.991 20.5633 108.5 17.6358 108.5 12.897Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                    </div>
                </div>
            </section>
          """,
          example: """
            <section class="bg-white dark:bg-gray-900">
                <div class="py-8 lg:py-16 mx-auto max-w-screen-xl px-4">
                    <h2 class="mb-8 lg:mb-16 text-3xl font-extrabold tracking-tight leading-tight text-center text-gray-900 dark:text-white md:text-4xl">You’ll be in good company</h2>
                    <div class="grid grid-cols-2 gap-8 text-gray-500 sm:gap-12 md:grid-cols-3 lg:grid-cols-6 dark:text-gray-400">
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 125 35" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M64.828 7.11521C64.828 8.52061 63.6775 9.65275 62.2492 9.65275C60.8209 9.65275 59.6704 8.52061 59.6704 7.11521C59.6704 5.70981 60.7813 4.57766 62.2492 4.57766C63.7171 4.6167 64.828 5.74883 64.828 7.11521ZM54.1953 12.2293C54.1953 12.4636 54.1953 12.854 54.1953 12.854C54.1953 12.854 52.9655 11.2923 50.3469 11.2923C46.0225 11.2923 42.6502 14.5327 42.6502 19.0221C42.6502 23.4726 45.9829 26.7518 50.3469 26.7518C53.0051 26.7518 54.1953 25.1513 54.1953 25.1513V25.815C54.1953 26.1272 54.4334 26.3615 54.7508 26.3615H57.9644V11.6828C57.9644 11.6828 55.0285 11.6828 54.7508 11.6828C54.4334 11.6828 54.1953 11.956 54.1953 12.2293ZM54.1953 21.6378C53.6002 22.4966 52.41 23.2383 50.9818 23.2383C48.4426 23.2383 46.4985 21.6768 46.4985 19.0221C46.4985 16.3675 48.4426 14.806 50.9818 14.806C52.3703 14.806 53.6399 15.5867 54.1953 16.4065V21.6378ZM60.3448 11.6828H64.1535V26.3615H60.3448V11.6828ZM117.237 11.2923C114.619 11.2923 113.389 12.854 113.389 12.854V4.6167H109.58V26.3615C109.58 26.3615 112.516 26.3615 112.794 26.3615C113.111 26.3615 113.349 26.0882 113.349 25.815V25.1513C113.349 25.1513 114.579 26.7518 117.198 26.7518C121.522 26.7518 124.895 23.4726 124.895 19.0221C124.895 14.5717 121.522 11.2923 117.237 11.2923ZM116.603 23.1993C115.135 23.1993 113.984 22.4575 113.389 21.5986V16.3675C113.984 15.5867 115.254 14.7668 116.603 14.7668C119.142 14.7668 121.086 16.3284 121.086 18.9831C121.086 21.6378 119.142 23.1993 116.603 23.1993ZM107.597 17.6557V26.4005H103.788V18.0852C103.788 15.6648 102.994 14.6888 100.852 14.6888C99.7015 14.6888 98.5113 15.2744 97.7574 16.1332V26.3615H93.9488V11.6828H96.964C97.2814 11.6828 97.5195 11.956 97.5195 12.2293V12.854C98.6302 11.7218 100.098 11.2923 101.566 11.2923C103.233 11.2923 104.621 11.7609 105.732 12.6977C107.081 13.7908 107.597 15.1962 107.597 17.6557ZM84.7048 11.2923C82.0862 11.2923 80.8564 12.854 80.8564 12.854V4.6167H77.0476V26.3615C77.0476 26.3615 79.9834 26.3615 80.2611 26.3615C80.5787 26.3615 80.8166 26.0882 80.8166 25.815V25.1513C80.8166 25.1513 82.0465 26.7518 84.665 26.7518C88.9895 26.7518 92.3617 23.4726 92.3617 19.0221C92.4015 14.5717 89.0292 11.2923 84.7048 11.2923ZM84.0699 23.1993C82.602 23.1993 81.4515 22.4575 80.8564 21.5986V16.3675C81.4515 15.5867 82.721 14.7668 84.0699 14.7668C86.6091 14.7668 88.5531 16.3284 88.5531 18.9831C88.5531 21.6378 86.6091 23.1993 84.0699 23.1993ZM73.7547 11.2923C74.9052 11.2923 75.5003 11.4876 75.5003 11.4876V14.9621C75.5003 14.9621 72.3264 13.908 70.3427 16.1332V26.4005H66.534V11.6828C66.534 11.6828 69.4699 11.6828 69.7476 11.6828C70.065 11.6828 70.3029 11.956 70.3029 12.2293V12.854C71.0171 12.0342 72.5644 11.2923 73.7547 11.2923ZM32.4423 24.4806C32.2699 24.0722 32.0976 23.6297 31.9252 23.2554C31.6493 22.6427 31.3736 22.0641 31.1322 21.5197L31.0978 21.4855C28.719 16.3804 26.1678 11.2073 23.4787 6.10219L23.3752 5.89799C23.0995 5.38748 22.8237 4.84294 22.5479 4.29839C22.2031 3.68577 21.8584 3.03913 21.3068 2.42652C20.2036 1.06516 18.6177 0.316406 16.9284 0.316406C15.2046 0.316406 13.6533 1.06516 12.5156 2.35845C11.9985 2.97107 11.6192 3.61771 11.2745 4.23032C10.9987 4.77486 10.7229 5.31941 10.4471 5.82992L10.3436 6.03413C7.68904 11.1392 5.10339 16.3124 2.7246 21.4175L2.69012 21.4855C2.44879 22.0301 2.17299 22.6087 1.89719 23.2214C1.72481 23.5957 1.55244 24.0041 1.38006 24.4466C0.93188 25.7058 0.793978 26.897 0.966355 28.1222C1.34558 30.6748 3.06935 32.8189 5.44815 33.7719C6.3445 34.1463 7.27534 34.3164 8.24065 34.3164C8.51645 34.3164 8.8612 34.2824 9.137 34.2483C10.2747 34.1122 11.4468 33.7378 12.5845 33.0912C13.9981 32.3083 15.3425 31.1852 16.8595 29.5517C18.3764 31.1852 19.7554 32.3083 21.1344 33.0912C22.2721 33.7378 23.4443 34.1122 24.5819 34.2483C24.8577 34.2824 25.2025 34.3164 25.4782 34.3164C26.4436 34.3164 27.4089 34.1463 28.2708 33.7719C30.6841 32.8189 32.3733 30.6408 32.7526 28.1222C33.0283 26.931 32.8904 25.7398 32.4423 24.4806ZM16.9259 25.893C15.1377 23.6468 13.9786 21.5327 13.5812 19.7488C13.4156 18.9891 13.3825 18.3284 13.4818 17.7338C13.5481 17.2053 13.7467 16.7429 14.0118 16.3465C14.6409 15.4546 15.7007 14.893 16.9259 14.893C18.1512 14.893 19.2441 15.4216 19.8402 16.3465C20.1051 16.7429 20.3037 17.2053 20.37 17.7338C20.4694 18.3284 20.4363 19.0221 20.2707 19.7488C19.8733 21.4995 18.7142 23.6136 16.9259 25.893ZM30.3665 27.6033C30.1305 29.3326 28.9509 30.8293 27.2993 31.4945C26.4903 31.8269 25.6139 31.9267 24.7376 31.8269C23.895 31.7273 23.0523 31.4611 22.176 30.9623C20.9624 30.2971 19.749 29.2662 18.3334 27.7363C20.558 25.0424 21.9062 22.5813 22.4118 20.3864C22.6477 19.3554 22.6815 18.4242 22.5804 17.5595C22.4456 16.7281 22.1422 15.9632 21.6703 15.298C20.6255 13.8014 18.8727 12.9367 16.9178 12.9367C14.9628 12.9367 13.21 13.8347 12.1652 15.298C11.6933 15.9632 11.39 16.7281 11.2551 17.5595C11.1203 18.4242 11.154 19.3887 11.4237 20.3864C11.9293 22.5813 13.3112 25.0757 15.5021 27.7695C14.1202 29.2994 12.873 30.3304 11.6596 30.9955C10.7832 31.4945 9.94059 31.7605 9.09795 31.8603C8.18787 31.9599 7.31152 31.8269 6.53628 31.5277C4.88468 30.8625 3.70497 29.366 3.46902 27.6365C3.36791 26.8051 3.43531 25.9737 3.77238 25.0424C3.8735 24.7098 4.04202 24.3774 4.21055 23.9782C4.4465 23.4461 4.71615 22.8807 4.9858 22.3153L5.0195 22.2489C7.34523 17.2935 9.83948 12.2383 12.4349 7.31623L12.536 7.11668C12.8056 6.61782 13.0753 6.0857 13.3449 5.58684C13.6146 5.05472 13.9179 4.55585 14.2886 4.12351C14.9965 3.32532 15.9403 2.89298 16.9852 2.89298C18.03 2.89298 18.9738 3.32532 19.6817 4.12351C20.0524 4.55585 20.3557 5.05472 20.6255 5.58684C20.8951 6.0857 21.1647 6.61782 21.4343 7.11668L21.5355 7.31623C24.0971 12.2716 26.5914 17.3267 28.9171 22.2821V22.3153C29.1867 22.8475 29.4227 23.4461 29.6924 23.9782C29.8609 24.3774 30.0294 24.7098 30.1305 25.0424C30.4003 25.9071 30.5013 26.7385 30.3665 27.6033Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 86 29" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M11.6008 10.2627V13.2312L18.6907 13.2281C18.4733 14.8653 17.9215 16.0641 17.0826 16.9031C16.0487 17.9378 14.4351 19.0766 11.6008 19.0766C7.23238 19.0766 3.81427 15.5531 3.81427 11.1808C3.81427 6.80853 7.23238 3.28487 11.6008 3.28487C13.9585 3.28487 15.6794 4.21232 16.9503 5.40473L19.0432 3.31011C17.2721 1.6161 14.9144 0.316406 11.6036 0.316406C5.62156 0.316406 0.589844 5.19338 0.589844 11.1808C0.589844 17.1682 5.62156 22.0451 11.6036 22.0451C14.8322 22.0451 17.2694 20.9852 19.1756 18.9979C21.1362 17.0356 21.7451 14.2818 21.7451 12.0546C21.7451 11.3921 21.6949 10.7802 21.5974 10.2627H11.6008ZM71.4046 21.6192V1.11445H68.4101V21.6192H71.4046ZM29.9511 22.0482C33.8151 22.0482 36.9643 19.0797 36.9643 15.0513C36.9643 10.9945 33.8151 8.05451 29.9511 8.05451C26.0857 8.05451 22.9365 10.9945 22.9365 15.0513C22.9365 19.0797 26.0857 22.0482 29.9511 22.0482ZM29.9511 10.8116C32.0691 10.8116 33.8945 12.534 33.8945 15.0513C33.8945 17.5404 32.0691 19.2911 29.9511 19.2911C27.833 19.2911 26.0076 17.5435 26.0076 15.0513C26.0076 12.534 27.833 10.8116 29.9511 10.8116ZM45.0825 22.0482C48.9465 22.0482 52.0957 19.0797 52.0957 15.0513C52.0957 10.9945 48.9465 8.05451 45.0825 8.05451C41.2171 8.05451 38.0679 10.9977 38.0679 15.0513C38.0679 19.0797 41.2171 22.0482 45.0825 22.0482ZM45.0825 10.8116C47.2005 10.8116 49.0259 12.534 49.0259 15.0513C49.0259 17.5404 47.2005 19.2911 45.0825 19.2911C42.9644 19.2911 41.139 17.5435 41.139 15.0513C41.139 12.534 42.9644 10.8116 45.0825 10.8116ZM66.5972 8.48038V21.0387C66.5972 26.2059 63.5512 28.3164 59.9519 28.3164C56.563 28.3164 54.523 26.0482 53.7539 24.1934L56.4265 23.0798C56.903 24.2186 58.0694 25.5624 59.9477 25.5624C62.2525 25.5624 63.6807 24.1397 63.6807 21.4615V20.4552H63.5734C62.8865 21.3037 61.5627 22.0451 59.892 22.0451C56.3958 22.0451 53.1923 18.9977 53.1923 15.0766C53.1923 11.1271 56.3958 8.05451 59.892 8.05451C61.5585 8.05451 62.8837 8.79579 63.5734 9.6192H63.6807V8.48038H66.5972ZM63.8981 15.0766C63.8981 12.6129 62.2553 10.8116 60.1651 10.8116C58.0471 10.8116 56.2732 12.6129 56.2732 15.0766C56.2732 17.5152 58.0471 19.2911 60.1651 19.2911C62.2553 19.2911 63.8981 17.5152 63.8981 15.0766ZM83.0747 17.3542L85.4575 18.9442C84.6883 20.083 82.835 22.0451 79.6315 22.0451C75.6602 22.0451 72.6935 18.9726 72.6935 15.0483C72.6935 10.8874 75.6853 8.05143 79.2887 8.05143C82.9172 8.05143 84.6911 10.941 85.2721 12.5026L85.5898 13.2976L76.2426 17.1713C76.9589 18.5751 78.0708 19.2912 79.6315 19.2912C81.1949 19.2912 82.2804 18.5215 83.0747 17.3542ZM75.7382 14.8369L81.9864 12.2407C81.6436 11.3668 80.6097 10.758 79.3918 10.758C77.8326 10.758 75.6602 12.1366 75.7382 14.8369Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-8 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 151 34" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <g clip-path="url(#clip0_3753_27919)"><path d="M150.059 16.1144V13.4753H146.783V9.37378L146.673 9.40894L143.596 10.3464H143.538V13.4519H138.682V11.7175C138.682 10.9207 138.869 10.2996 139.221 9.8894C139.572 9.47925 140.088 9.27417 140.721 9.27417C141.189 9.27417 141.682 9.39136 142.15 9.60229L142.268 9.64917V6.88237L142.221 6.85894C141.775 6.70073 141.166 6.6187 140.416 6.6187C139.467 6.6187 138.6 6.82964 137.838 7.24448C137.076 7.64292 136.479 8.24058 136.068 8.99058C135.646 9.74058 135.436 10.6078 135.436 11.557V13.4554H133.162V16.0921H135.447V27.2015H138.717V16.0921H143.577V23.1468C143.577 26.0531 144.943 27.5296 147.655 27.5296C148.1 27.5296 148.569 27.4734 149.038 27.3773C149.524 27.2718 149.858 27.1664 150.045 27.0609L150.092 27.0374V24.3773L149.96 24.4664C149.784 24.5835 149.561 24.6855 149.304 24.7558C149.046 24.8261 148.823 24.873 148.657 24.873C148.024 24.873 147.555 24.7089 147.267 24.3726C146.969 24.0386 146.821 23.4468 146.821 22.6148V16.1226H150.079L150.072 16.1062L150.059 16.1144ZM125.813 24.88C124.626 24.88 123.689 24.4851 123.024 23.7082C122.364 22.9289 122.028 21.8167 122.028 20.4035C122.028 18.9457 122.364 17.8019 123.028 17.0097C123.689 16.2222 124.617 15.8214 125.789 15.8214C126.925 15.8214 127.816 16.2035 128.472 16.9582C129.129 17.7175 129.457 18.8496 129.457 20.3238C129.457 21.8167 129.152 22.964 128.543 23.7304C127.933 24.4921 127.019 24.8789 125.824 24.8789L125.813 24.88ZM125.964 13.1449C123.703 13.1449 121.9 13.8082 120.616 15.1183C119.339 16.4308 118.685 18.2425 118.685 20.5089C118.685 22.6652 119.318 24.3937 120.575 25.6535C121.829 26.9191 123.536 27.5753 125.646 27.5753C127.839 27.5753 129.607 26.8957 130.886 25.5773C132.175 24.2507 132.815 22.4531 132.815 20.2417C132.815 18.055 132.206 16.3089 130.999 15.0621C129.792 13.8035 128.1 13.1683 125.96 13.1683L125.964 13.1449ZM113.397 13.1683C111.85 13.1683 110.58 13.5621 109.6 14.3402C108.625 15.123 108.124 16.1449 108.124 17.3871C108.124 18.0363 108.234 18.6058 108.447 19.098C108.658 19.5832 108.986 20.0121 109.425 20.373C109.858 20.7246 110.526 21.0996 111.417 21.4839C112.167 21.7886 112.718 22.0464 113.074 22.2574C113.425 22.4531 113.674 22.6558 113.8 22.8515C113.941 23.039 114.011 23.3085 114.011 23.625C114.011 24.5554 113.322 25.0031 111.902 25.0031C111.372 25.0031 110.77 24.8929 110.111 24.675C109.447 24.4593 108.83 24.1476 108.275 23.7468L108.134 23.6531V26.7937L108.181 26.8171C108.65 27.0281 109.228 27.2156 109.916 27.3562C110.601 27.5085 111.228 27.5789 111.767 27.5789C113.443 27.5789 114.791 27.1804 115.775 26.4023C116.759 25.6148 117.263 24.5625 117.263 23.2804C117.263 22.3546 116.994 21.5578 116.461 20.9191C115.933 20.2792 115.019 19.6957 113.738 19.18C112.727 18.7699 112.074 18.43 111.793 18.1722C111.535 17.9191 111.414 17.5628 111.414 17.1128C111.414 16.7144 111.579 16.3933 111.912 16.1355C112.248 15.8718 112.716 15.7406 113.302 15.7406C113.847 15.7406 114.404 15.8226 114.966 15.9925C115.517 16.166 116.004 16.391 116.408 16.6675L116.545 16.7613V13.7613L116.498 13.7378C116.117 13.5738 115.623 13.4367 115.021 13.3277C114.424 13.214 113.881 13.1636 113.41 13.1636L113.397 13.1683ZM99.582 24.8941C98.3984 24.8941 97.4609 24.5027 96.8047 23.7222C96.1367 22.9488 95.8027 21.8355 95.8027 20.4175C95.8027 18.9644 96.1379 17.816 96.8035 17.0273C97.4598 16.2398 98.3902 15.839 99.5574 15.839C100.694 15.839 101.596 16.221 102.247 16.9757C102.894 17.7375 103.231 18.8695 103.231 20.3437C103.231 21.8343 102.915 22.9804 102.305 23.748C101.708 24.5097 100.794 24.8964 99.5867 24.8964L99.582 24.8941ZM99.7508 13.166C97.4773 13.166 95.6727 13.8269 94.3953 15.1371C93.1098 16.4496 92.4617 18.2601 92.4617 20.5277C92.4617 22.6839 93.0945 24.4113 94.3402 25.6722C95.5965 26.9378 97.3004 27.5941 99.4086 27.5941C101.612 27.5941 103.37 26.9144 104.659 25.5902C105.941 24.2613 106.592 22.4636 106.592 20.2523C106.592 18.0644 105.983 16.3183 104.787 15.0726C103.58 13.8128 101.886 13.1777 99.7484 13.1777L99.7508 13.166ZM87.5164 15.8824V13.4917H84.282V27.2378H87.5164V20.2066C87.5164 19.0113 87.7859 18.0269 88.3215 17.2828C88.8488 16.5421 89.552 16.1812 90.4074 16.1812C90.7004 16.1812 91.0285 16.2281 91.3895 16.3218C91.741 16.4156 91.9941 16.5093 92.1395 16.6265L92.2801 16.7203V13.4625L92.2285 13.439C91.9238 13.3031 91.502 13.2375 90.9629 13.2375C90.1543 13.2375 89.4277 13.5 88.8043 14.0109C88.2535 14.4656 87.8586 15.0843 87.5562 15.8578H87.4977L87.527 15.8812L87.5164 15.8824ZM78.4695 13.1636C76.9812 13.1636 75.657 13.4742 74.532 14.1011C73.3977 14.7339 72.5281 15.6246 71.9305 16.773C71.3445 17.9097 71.0398 19.2398 71.0398 20.7222C71.0398 22.023 71.3352 23.2113 71.907 24.2636C72.4859 25.3183 73.3016 26.1386 74.3328 26.7128C75.357 27.2789 76.5477 27.5683 77.8648 27.5683C79.4023 27.5683 80.7125 27.2636 81.7672 26.6542L81.8141 26.6308V23.6636L81.6734 23.7609C81.1965 24.1124 80.6656 24.3878 80.0914 24.5871C79.5195 24.7863 78.9992 24.8871 78.5445 24.8871C77.2719 24.8871 76.2547 24.4886 75.5141 23.7093C74.7641 22.9124 74.3891 21.8109 74.3891 20.4281C74.3891 19.0218 74.7875 17.8968 75.5562 17.0765C76.3297 16.2328 77.3469 15.8109 78.5914 15.8109C79.6461 15.8109 80.6855 16.1742 81.6652 16.8773L81.8059 16.971V13.8539L81.7672 13.8304C81.398 13.6195 80.8965 13.4554 80.2672 13.3218C79.6508 13.1929 79.0437 13.1296 78.4648 13.1296L78.4695 13.1636ZM68.8203 13.4578H65.5906V27.2156H68.825V13.4578H68.8203ZM67.2266 7.61011C66.6945 7.61011 66.2305 7.79058 65.8484 8.14917C65.4664 8.51011 65.2719 8.96245 65.2719 9.49683C65.2719 10.0242 65.4676 10.4695 65.8461 10.821C66.2211 11.1726 66.6898 11.346 67.2289 11.346C67.768 11.346 68.2367 11.1703 68.6176 10.8187C69.002 10.4671 69.1965 10.0218 69.1965 9.49448C69.1965 8.97886 69.009 8.53355 68.634 8.15855C68.259 7.80698 67.7902 7.61948 67.2277 7.61948L67.2266 7.61011ZM59.1535 12.4593V27.2249H62.4582V8.05425H57.8879L52.0953 22.3019L46.4586 8.0519H41.7078V27.2378H44.8133V12.4781H44.9188L50.8719 27.2414H53.2098L59.0691 12.4792H59.1805L59.1629 12.4722L59.1535 12.4593ZM16.884 18.4242H32.0949V33.648H16.8605L16.8816 18.4347L16.884 18.4242ZM0.0828125 18.4335H15.2914V33.648H0.078125L0.0828125 18.4347V18.4335ZM16.8852 1.63237H32.0961V16.8433H16.8758L16.8852 1.62769V1.63237ZM0.0828125 1.63003H15.2914V16.8433H0.078125L0.0828125 1.62769V1.63003Z" fill="currentColor"/></g><defs><clipPath id="clip0_3753_27919"><rect width="150" height="32.8125" fill="white" transform="translate(0.0820312 0.835449)"/></clipPath></defs>
                            </svg>
                        </.page_link>

                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 124 38" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path d="M50.8299 17.3952C54.7246 18.342 56.3124 19.8121 56.3124 22.4701C56.3124 25.615 53.9096 27.6473 50.1907 27.6473C47.5621 27.6473 45.1252 26.7135 43.1446 24.9452C43.104 24.9089 43.0791 24.8582 43.0754 24.8038C43.0716 24.7494 43.0893 24.6957 43.1246 24.6542L44.8747 22.5724C44.8926 22.5512 44.9145 22.5336 44.9392 22.5209C44.9639 22.5082 44.9909 22.5005 45.0185 22.4983C45.0462 22.4961 45.0741 22.4995 45.1005 22.5082C45.1269 22.5169 45.1513 22.5307 45.1723 22.5489C46.8747 24.0226 48.3966 24.6506 50.2619 24.6506C51.9419 24.6506 52.9857 23.9232 52.9857 22.7541C52.9857 21.6986 52.4694 21.1088 49.4104 20.4043C45.8174 19.5351 43.7374 18.4108 43.7374 15.2323C43.7374 12.2686 46.1484 10.1986 49.5991 10.1986C51.9455 10.1986 53.9548 10.8937 55.7384 12.3244C55.8243 12.3938 55.8419 12.5185 55.7778 12.609L54.2165 14.8084C54.2002 14.831 54.1796 14.8501 54.1558 14.8647C54.1321 14.8793 54.1057 14.8891 54.0781 14.8935C54.0506 14.8978 54.0224 14.8967 53.9953 14.8902C53.9682 14.8837 53.9427 14.8718 53.9202 14.8554C52.4218 13.7381 50.9928 13.1959 49.5509 13.1959C48.0643 13.1959 47.0646 13.9104 47.0646 14.9718C47.0646 16.095 47.635 16.6302 50.8305 17.3934L50.8299 17.3952ZM64.7256 14.2432C63.1144 14.2432 61.7924 14.8783 60.7016 16.1779V14.7137C60.7016 14.6582 60.6795 14.6049 60.6403 14.5657C60.601 14.5264 60.5478 14.5043 60.4922 14.5043H57.6308C57.5752 14.5043 57.522 14.5264 57.4827 14.5657C57.4435 14.6049 57.4214 14.6582 57.4214 14.7137V30.9851C57.4214 31.0998 57.5155 31.1939 57.6308 31.1939H60.4928C60.6087 31.1939 60.7028 31.0998 60.7028 30.9846V25.8479C61.793 27.0711 63.1156 27.6697 64.7274 27.6697C67.7235 27.6697 70.755 25.3645 70.755 20.9565C70.755 16.5484 67.7218 14.2432 64.7256 14.2432ZM67.4248 20.9571C67.4248 23.2011 66.0429 24.7676 64.0635 24.7676C62.1053 24.7676 60.6293 23.1299 60.6293 20.9571C60.6293 18.7842 62.1053 17.1465 64.0635 17.1465C66.0111 17.1465 67.4254 18.7489 67.4254 20.9571H67.4248ZM78.5255 14.2432C74.6679 14.2432 71.6465 17.2129 71.6465 21.0059C71.6465 24.7565 74.6467 27.695 78.4773 27.695C82.3485 27.695 85.3793 24.7347 85.3793 20.9571C85.3793 17.1923 82.3684 14.2427 78.5249 14.2427L78.5255 14.2432ZM78.5249 24.7906C76.4726 24.7906 74.926 23.1423 74.926 20.9565C74.926 18.7618 76.4197 17.1694 78.4779 17.1694C80.542 17.1694 82.1003 18.8177 82.1003 21.0047C82.1003 23.1981 80.5961 24.79 78.5249 24.79V24.7906ZM93.6168 14.5043C93.7326 14.5043 93.8261 14.5984 93.8261 14.7137V17.1735C93.8262 17.201 93.8208 17.2282 93.8104 17.2536C93.7999 17.279 93.7846 17.3021 93.7652 17.3215C93.7458 17.341 93.7227 17.3564 93.6974 17.3669C93.672 17.3774 93.6448 17.3829 93.6173 17.3829H90.4683V23.2993C90.4683 24.2343 90.8788 24.6506 91.7973 24.6506C92.3818 24.6538 92.9582 24.5145 93.4768 24.2449C93.5089 24.229 93.5444 24.2215 93.5802 24.2232C93.6159 24.2249 93.6507 24.2356 93.6811 24.2545C93.7115 24.2733 93.7366 24.2996 93.7541 24.3308C93.7715 24.3621 93.7807 24.3973 93.7808 24.433V26.7747C93.7808 26.8494 93.7397 26.9199 93.675 26.957C92.8723 27.4115 92.0208 27.6232 90.9934 27.6232C88.4689 27.6232 87.1887 26.3195 87.1887 23.7468V17.3834H85.8127C85.7853 17.3834 85.7581 17.3779 85.7328 17.3673C85.7075 17.3568 85.6846 17.3413 85.6652 17.3219C85.6459 17.3024 85.6306 17.2794 85.6202 17.254C85.6098 17.2287 85.6044 17.2015 85.6045 17.1741V14.7137C85.6045 14.5984 85.6974 14.5043 85.8127 14.5043H87.1887V11.2841C87.1887 11.1689 87.2828 11.0748 87.3993 11.0748H90.2607C90.3766 11.0748 90.4701 11.1689 90.4701 11.2841V14.5043H93.6191H93.6168ZM109.48 14.5167C109.566 14.5167 109.644 14.5696 109.675 14.6519L113.018 23.3751L116.07 14.6566C116.085 14.6155 116.112 14.5798 116.147 14.5545C116.183 14.5293 116.225 14.5156 116.269 14.5155H119.248C119.282 14.5155 119.316 14.5238 119.346 14.5398C119.376 14.5558 119.402 14.5789 119.421 14.6072C119.441 14.6354 119.452 14.668 119.456 14.7019C119.46 14.7359 119.455 14.7702 119.442 14.8019L114.477 27.6332C113.448 30.2812 112.279 31.2656 110.166 31.2656C109.036 31.2656 108.122 31.0316 107.108 30.4835C107.062 30.4584 107.027 30.4163 107.01 30.366C106.993 30.3157 106.997 30.261 107.019 30.213L107.989 28.0843C108.001 28.058 108.018 28.0345 108.04 28.0151C108.061 27.9957 108.086 27.9808 108.113 27.9714C108.14 27.9626 108.169 27.9595 108.198 27.9622C108.227 27.9649 108.255 27.9734 108.28 27.9872C108.823 28.2842 109.354 28.4342 109.859 28.4342C110.482 28.4342 110.939 28.2295 111.404 27.1981L107.311 17.3834H104.638V27.201C104.638 27.3169 104.544 27.4109 104.429 27.4109H101.567C101.539 27.4109 101.512 27.4055 101.486 27.395C101.461 27.3844 101.438 27.3689 101.418 27.3494C101.399 27.3299 101.384 27.3068 101.373 27.2813C101.363 27.2558 101.357 27.2286 101.357 27.201V17.3834H99.9824C99.9269 17.383 99.8738 17.3607 99.8345 17.3215C99.7952 17.2822 99.773 17.229 99.7725 17.1735V14.7019C99.7725 14.5861 99.8666 14.492 99.9818 14.492H101.357V13.8863C101.357 11.0719 102.754 9.58291 105.398 9.58291C106.484 9.58291 107.209 9.75638 107.777 9.92398C107.866 9.95162 107.925 10.0334 107.925 10.1251V12.5361C107.926 12.5695 107.918 12.6024 107.903 12.6322C107.888 12.662 107.866 12.6878 107.839 12.7074C107.813 12.727 107.781 12.7398 107.748 12.7448C107.715 12.7498 107.682 12.7468 107.65 12.7361C107.113 12.5573 106.634 12.4385 106.038 12.4385C105.038 12.4385 104.591 12.9578 104.591 14.1215V14.5167H109.479H109.48ZM98.2289 14.5043C98.3441 14.5043 98.4382 14.5984 98.4382 14.7137V27.2004C98.4382 27.3157 98.3441 27.4098 98.2283 27.4098H95.3662C95.3106 27.4098 95.2573 27.3877 95.218 27.3485C95.1786 27.3092 95.1564 27.256 95.1563 27.2004V14.7137C95.1563 14.5984 95.2504 14.5043 95.3656 14.5043H98.2277H98.2289ZM96.8122 8.81903C97.3565 8.81903 97.8786 9.03525 98.2634 9.42013C98.6483 9.80502 98.8645 10.327 98.8645 10.8713C98.8645 11.4156 98.6483 11.9377 98.2634 12.3225C97.8786 12.7074 97.3565 12.9236 96.8122 12.9236C96.2679 12.9236 95.7459 12.7074 95.361 12.3225C94.9762 11.9377 94.7599 11.4156 94.7599 10.8713C94.7599 10.327 94.9762 9.80502 95.361 9.42013C95.7459 9.03525 96.2679 8.81903 96.8122 8.81903ZM121.886 18.5184C121.621 18.5194 121.359 18.468 121.114 18.3671C120.869 18.2663 120.646 18.118 120.459 17.9307C120.272 17.7435 120.124 17.5211 120.023 17.2763C119.922 17.0314 119.871 16.7691 119.872 16.5043C119.872 16.2385 119.924 15.9752 120.026 15.7296C120.127 15.484 120.277 15.2608 120.465 15.0729C120.653 14.8849 120.876 14.7358 121.122 14.6341C121.367 14.5324 121.63 14.4801 121.896 14.4802C122.161 14.4791 122.423 14.5303 122.668 14.631C122.913 14.7318 123.135 14.88 123.323 15.0671C123.51 15.2543 123.658 15.4766 123.759 15.7214C123.86 15.9661 123.911 16.2284 123.91 16.4931C123.91 16.7591 123.858 17.0225 123.756 17.2682C123.655 17.514 123.506 17.7373 123.318 17.9254C123.13 18.1135 122.906 18.2627 122.661 18.3646C122.415 18.4664 122.152 18.5189 121.886 18.519V18.5184ZM121.896 14.6808C120.865 14.6808 120.084 15.5011 120.084 16.5049C120.084 17.5087 120.859 18.3179 121.886 18.3179C122.917 18.3179 123.699 17.4981 123.699 16.4937C123.699 15.4899 122.922 14.6808 121.896 14.6808ZM122.343 16.7007L122.912 17.4981H122.432L121.92 16.7666H121.479V17.4981H121.077V15.3841H122.02C122.51 15.3841 122.834 15.6358 122.834 16.0586C122.834 16.4055 122.634 16.6172 122.343 16.6995L122.343 16.7007ZM122.002 15.7469H121.478V16.4149H122.002C122.264 16.4149 122.419 16.2867 122.419 16.0797C122.419 15.8622 122.264 15.7463 122.002 15.7463V15.7469ZM18.9768 0.305176C8.75288 0.305176 0.464844 8.70847 0.464844 18.933C0.464256 28.54 7.78083 36.2953 17.1462 37.4714H20.8074C30.1728 36.2953 37.4893 28.54 37.4893 18.9324C37.4893 8.70847 29.2007 0.305176 18.9774 0.305176H18.9768ZM27.4665 27.0064C27.3877 27.1359 27.284 27.2486 27.1616 27.3379C27.0391 27.4273 26.9002 27.4917 26.7528 27.5273C26.6054 27.5629 26.4525 27.5691 26.3027 27.5455C26.1529 27.5219 26.0093 27.469 25.88 27.3898C21.5325 24.733 16.0612 24.1331 9.61732 25.605C9.46966 25.639 9.31676 25.6435 9.16736 25.6183C9.01796 25.5931 8.87499 25.5387 8.74664 25.4582C8.61829 25.3777 8.50707 25.2726 8.41934 25.1491C8.33162 25.0256 8.26911 24.886 8.23539 24.7382C8.20146 24.5905 8.19701 24.4375 8.22229 24.2881C8.24756 24.1386 8.30207 23.9956 8.3827 23.8672C8.46332 23.7389 8.56848 23.6277 8.69214 23.54C8.8158 23.4523 8.95554 23.3899 9.10336 23.3563C16.1553 21.745 22.204 22.439 27.0837 25.4204C27.3446 25.5803 27.5314 25.8371 27.603 26.1346C27.6747 26.4321 27.6254 26.7458 27.4659 27.007L27.4665 27.0064ZM29.7317 21.9656C29.5314 22.2916 29.2099 22.5248 28.8377 22.6139C28.4656 22.703 28.0733 22.6407 27.747 22.4407C22.7721 19.3828 15.1862 18.4966 9.29977 20.2837C8.93342 20.3943 8.53819 20.3552 8.2006 20.175C7.86301 19.9948 7.61058 19.6882 7.49856 19.3223C7.26922 18.5578 7.6985 17.7539 8.46121 17.5228C15.1856 15.4823 23.5436 16.4702 29.2577 19.9809C29.5837 20.1813 29.8168 20.5029 29.9058 20.875C29.9948 21.2472 29.9324 21.6394 29.7323 21.9656H29.7317ZM29.9269 16.7166C23.9594 13.173 14.1165 12.8472 8.42004 14.5761C7.98054 14.7093 7.50613 14.6624 7.10118 14.4458C6.69622 14.2292 6.3939 13.8606 6.26071 13.4211C6.12752 12.9816 6.17437 12.5072 6.39096 12.1023C6.60756 11.6973 6.97615 11.395 7.41565 11.2618C13.9548 9.27712 24.8256 9.66053 31.6952 13.7375C31.8908 13.8535 32.0617 14.0069 32.198 14.1889C32.3343 14.371 32.4334 14.5781 32.4897 14.7984C32.5459 15.0188 32.5582 15.248 32.5258 15.4731C32.4934 15.6982 32.417 15.9148 32.3009 16.1103C32.185 16.3061 32.0316 16.477 31.8495 16.6134C31.6674 16.7498 31.4603 16.849 31.2398 16.9053C31.0194 16.9615 30.79 16.9738 30.5648 16.9413C30.3397 16.9088 30.1231 16.8323 29.9275 16.716L29.9269 16.7166Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-9 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 137 37" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path d="M53.3228 13.9636C51.5883 13.9636 50.7303 15.3285 50.3366 16.209C50.1166 16.7006 50.0551 17.0893 49.8767 17.0893C49.6253 17.0893 49.8054 16.7514 49.5997 16.0022C49.329 15.0165 48.5133 13.9636 46.78 13.9636C44.9577 13.9636 44.1775 15.5032 43.8075 16.3493C43.5545 16.9276 43.5542 17.0893 43.3597 17.0893C43.0778 17.0893 43.3113 16.6298 43.4381 16.0897C43.688 15.0263 43.498 14.2136 43.498 14.2136H40.6094V25.0758H44.5523C44.5523 25.0758 44.5523 20.5363 44.5523 19.6714C44.5523 18.6054 44.9982 17.2528 45.7625 17.2528C46.6456 17.2528 46.8224 17.931 46.8224 19.1869C46.8224 20.3255 46.8224 25.0781 46.8224 25.0781H50.7812C50.7812 25.0781 50.7812 20.511 50.7812 19.6714C50.7812 18.7226 51.1684 17.2528 51.9972 17.2528C52.8926 17.2528 53.0511 18.2056 53.0511 19.1869C53.0511 20.1682 53.0511 25.0758 53.0511 25.0758H56.9387C56.9387 25.0758 56.9387 20.7719 56.9387 18.6882C56.9387 15.8535 55.9395 13.9636 53.3228 13.9636Z" fill="currentColor"/>
                                <path d="M120.249 13.9636C118.514 13.9636 117.656 15.3285 117.262 16.209C117.042 16.7006 116.981 17.0893 116.802 17.0893C116.551 17.0893 116.719 16.6601 116.526 16.0022C116.237 15.0217 115.518 13.9636 113.706 13.9636C111.884 13.9636 111.103 15.5032 110.733 16.3493C110.48 16.9276 110.48 17.0893 110.286 17.0893C110.004 17.0893 110.237 16.6298 110.364 16.0897C110.614 15.0263 110.424 14.2136 110.424 14.2136H107.535V25.0758H111.478C111.478 25.0758 111.478 20.5363 111.478 19.6714C111.478 18.6054 111.924 17.2528 112.688 17.2528C113.571 17.2528 113.748 17.931 113.748 19.1869C113.748 20.3255 113.748 25.0781 113.748 25.0781H117.707C117.707 25.0781 117.707 20.511 117.707 19.6714C117.707 18.7226 118.094 17.2528 118.923 17.2528C119.819 17.2528 119.977 18.2056 119.977 19.1869C119.977 20.1682 119.977 25.0758 119.977 25.0758H123.865C123.865 25.0758 123.865 20.7719 123.865 18.6882C123.865 15.8535 122.865 13.9636 120.249 13.9636Z" fill="currentColor"/>
                                <path d="M62.7138 22.5371C61.7709 22.7549 61.2821 22.4645 61.2821 21.8395C61.2821 20.9834 62.1676 20.6406 63.4315 20.6406C63.9887 20.6406 64.5126 20.6888 64.5126 20.6888C64.5126 21.0552 63.7172 22.3056 62.7138 22.5371ZM63.6737 13.9661C60.6534 13.9661 58.4862 15.0765 58.4862 15.0765V18.3405C58.4862 18.3405 60.8795 16.9645 62.821 16.9645C64.3707 16.9645 64.5611 17.8003 64.4905 18.494C64.4905 18.494 64.0437 18.3757 62.6797 18.3757C59.4661 18.3757 57.8438 19.8362 57.8438 22.1782C57.8438 24.3997 59.667 25.3284 61.2031 25.3284C63.4446 25.3284 64.4299 23.8221 64.7327 23.1075C64.9428 22.6117 64.9811 22.2776 65.1699 22.2776C65.3849 22.2776 65.3125 22.5172 65.3021 23.0107C65.2839 23.8748 65.3246 24.528 65.4616 25.0782H68.4334V19.7326C68.4334 16.395 67.2525 13.9661 63.6737 13.9661Z" fill="currentColor"/>
                                <path d="M74.9258 25.0783H78.8688V10.9255H74.9258V25.0783Z" fill="currentColor"/>
                                <path d="M83.2111 19.6471C83.2111 18.6705 84.1184 17.7819 85.7842 17.7819C87.5992 17.7819 89.059 18.6558 89.3864 18.8542V15.0765C89.3864 15.0765 88.2331 13.9661 85.3984 13.9661C82.4103 13.9661 79.9219 15.7146 79.9219 19.4781C79.9219 23.2415 82.1801 25.3284 85.3904 25.3284C87.898 25.3284 89.3928 23.9506 89.3928 23.9506V20.3624C88.9199 20.6271 87.6021 21.5415 85.8023 21.5415C83.8964 21.5415 83.2111 20.6648 83.2111 19.6471Z" fill="currentColor"/>
                                <path d="M97.373 13.9662C95.0905 13.9662 94.2223 16.1293 94.047 16.5049C93.8716 16.8804 93.785 17.0964 93.6415 17.0918C93.3923 17.0837 93.566 16.6308 93.6631 16.3375C93.8467 15.7834 94.2357 14.3297 94.2357 12.543C94.2357 11.3311 94.0718 10.9255 94.0718 10.9255H90.668V25.0783H94.611C94.611 25.0783 94.611 20.5543 94.611 19.6741C94.611 18.7937 94.9623 17.2554 95.9556 17.2554C96.7784 17.2554 97.036 17.8651 97.036 19.0927C97.036 20.3201 97.036 25.0783 97.036 25.0783H100.979C100.979 25.0783 100.979 21.7679 100.979 19.3289C100.979 16.5406 100.517 13.9662 97.373 13.9662Z" fill="currentColor"/>
                                <path d="M102.258 14.2285V25.0782H106.201V14.2285C106.201 14.2285 105.538 14.6162 104.233 14.6162C102.929 14.6162 102.258 14.2285 102.258 14.2285Z" fill="currentColor"/>
                                <path d="M104.218 10.8157C102.885 10.8157 101.805 11.521 101.805 12.391C101.805 13.2609 102.885 13.9662 104.218 13.9662C105.551 13.9662 106.632 13.2609 106.632 12.391C106.632 11.521 105.551 10.8157 104.218 10.8157Z" fill="currentColor"/>
                                <path d="M69.707 14.2285V25.0782H73.6499V14.2285C73.6499 14.2285 72.9872 14.6162 71.6825 14.6162C70.3779 14.6162 69.707 14.2285 69.707 14.2285Z" fill="currentColor"/>
                                <path d="M71.6674 10.8157C70.3345 10.8157 69.2539 11.521 69.2539 12.391C69.2539 13.2609 70.3345 13.9662 71.6674 13.9662C73.0005 13.9662 74.0811 13.2609 74.0811 12.391C74.0811 11.521 73.0005 10.8157 71.6674 10.8157Z" fill="currentColor"/>
                                <path d="M130.616 22.744C129.712 22.744 129.047 21.5972 129.047 19.9993C129.047 18.4475 129.73 17.2552 130.585 17.2552C131.682 17.2552 132.15 18.2614 132.15 19.9993C132.15 21.8071 131.719 22.744 130.616 22.744ZM131.699 13.9636C129.672 13.9636 128.743 15.4835 128.339 16.3493C128.072 16.9214 128.086 17.0893 127.891 17.0893C127.609 17.0893 127.843 16.6298 127.97 16.0897C128.219 15.0263 128.029 14.2136 128.029 14.2136H125.141V28.0756H129.084C129.084 28.0756 129.084 25.8073 129.084 23.6807C129.55 24.4722 130.414 25.3179 131.747 25.3179C134.598 25.3179 136.033 22.9056 136.033 19.6462C136.033 15.952 134.315 13.9636 131.699 13.9636Z" fill="currentColor"/>
                                <path d="M26.682 17.2446C26.9471 17.213 27.2012 17.2115 27.4346 17.2446C27.5697 16.9348 27.593 16.4007 27.4714 15.819C27.2907 14.9545 27.0463 14.4313 26.5411 14.5127C26.036 14.5941 26.0173 15.2205 26.1979 16.0851C26.2995 16.5714 26.4804 16.987 26.682 17.2446Z" fill="currentColor"/>
                                <path d="M22.3442 17.9286C22.7056 18.0873 22.9278 18.1924 23.0147 18.1005C23.0706 18.0433 23.054 17.934 22.9677 17.7929C22.7893 17.5017 22.4222 17.2064 22.033 17.0405C21.2368 16.6978 20.2872 16.8118 19.5546 17.3381C19.3129 17.5153 19.0836 17.7608 19.1164 17.9098C19.1271 17.958 19.1633 17.9943 19.2481 18.0062C19.4476 18.029 20.1443 17.6767 20.9468 17.6276C21.5133 17.5929 21.9827 17.7701 22.3442 17.9286Z" fill="currentColor"/>
                                <path d="M21.6149 18.3436C21.1441 18.4179 20.8844 18.5732 20.7177 18.7175C20.5755 18.8417 20.4875 18.9792 20.4883 19.0759C20.4886 19.1219 20.5086 19.1484 20.5243 19.1618C20.5458 19.1806 20.5712 19.1911 20.6017 19.1911C20.7081 19.1911 20.9462 19.0955 20.9462 19.0955C21.6014 18.861 22.0335 18.8895 22.4618 18.9383C22.6985 18.9648 22.8103 18.9795 22.8622 18.8984C22.8776 18.8751 22.8962 18.8247 22.8488 18.7479C22.7385 18.569 22.2632 18.2666 21.6149 18.3436" fill="currentColor"/>
                                <path d="M25.2163 19.8666C25.5358 20.0237 25.8877 19.962 26.0024 19.7289C26.1169 19.4959 25.9506 19.1796 25.6309 19.0224C25.3113 18.8655 24.9594 18.927 24.8448 19.1601C24.7303 19.3933 24.8965 19.7094 25.2163 19.8666Z" fill="currentColor"/>
                                <path d="M27.2703 18.0709C27.0106 18.0664 26.7953 18.3516 26.7892 18.7076C26.7831 19.0638 26.9888 19.356 27.2485 19.3604C27.5081 19.3649 27.7236 19.0797 27.7295 18.7237C27.7356 18.3674 27.5299 18.0752 27.2703 18.0709Z" fill="currentColor"/>
                                <path d="M9.83004 24.4919C9.76544 24.411 9.65932 24.4356 9.55655 24.4596C9.48477 24.4764 9.40345 24.4952 9.31429 24.4937C9.1233 24.4899 8.96157 24.4085 8.87074 24.2689C8.75244 24.0872 8.75928 23.8163 8.88991 23.5064C8.90748 23.4644 8.92824 23.418 8.95084 23.3674C9.15903 22.9001 9.50765 22.118 9.11629 21.3728C8.82172 20.812 8.34133 20.4626 7.76373 20.3893C7.20923 20.319 6.63835 20.5246 6.27421 20.9263C5.69973 21.5601 5.60995 22.4226 5.72105 22.7274C5.76179 22.8389 5.82544 22.8698 5.87174 22.8761C5.96945 22.8892 6.11398 22.8181 6.20453 22.5745C6.211 22.557 6.21962 22.5298 6.23042 22.4953C6.27082 22.3666 6.34593 22.1268 6.46897 21.9346C6.61733 21.7028 6.8484 21.5432 7.11962 21.4851C7.39594 21.4259 7.67834 21.4787 7.91474 21.6335C8.31723 21.8967 8.47219 22.3898 8.30037 22.8604C8.21157 23.1037 8.06727 23.569 8.09913 23.9514C8.16344 24.7251 8.63936 25.0359 9.06699 25.069C9.48275 25.0845 9.77331 24.8513 9.84682 24.6806C9.89021 24.5797 9.85359 24.5183 9.83005 24.4919" fill="currentColor"/>
                                <path d="M13.781 10.2801C15.137 8.71317 16.8063 7.35092 18.3016 6.58601C18.3533 6.55944 18.4082 6.61569 18.3802 6.66639C18.2614 6.88141 18.0329 7.34188 17.9604 7.69111C17.9491 7.74554 18.0083 7.78647 18.0542 7.75518C18.9845 7.12106 20.6029 6.44157 22.0223 6.35422C22.0833 6.35044 22.1128 6.42867 22.0643 6.46589C21.8484 6.63154 21.6123 6.86065 21.4398 7.09244C21.4104 7.13187 21.4381 7.18868 21.4873 7.18898C22.484 7.19608 23.8891 7.54489 24.805 8.05859C24.8669 8.09327 24.8227 8.21326 24.7535 8.19739C23.3678 7.87989 21.0996 7.63891 18.7435 8.21358C16.6401 8.72668 15.0346 9.51873 13.8634 10.3705C13.8042 10.4137 13.7331 10.3355 13.781 10.2801L13.781 10.2801ZM20.5345 25.4617C20.5346 25.462 20.5348 25.4626 20.5349 25.4626C20.5352 25.463 20.5353 25.4638 20.5357 25.4642C20.5353 25.4634 20.5349 25.4626 20.5345 25.4617ZM26.1264 26.1218C26.1666 26.1049 26.1944 26.0591 26.1896 26.0136C26.184 25.9575 26.134 25.9167 26.0779 25.9225C26.0779 25.9225 23.1841 26.3507 20.4504 25.3501C20.7482 24.3823 21.5399 24.7317 22.7367 24.8283C24.8938 24.9569 26.827 24.6418 28.2558 24.2316C29.494 23.8765 31.12 23.1759 32.3831 22.1789C32.8091 23.1148 32.9595 24.1446 32.9595 24.1446C32.9595 24.1446 33.2893 24.0857 33.5648 24.2552C33.8252 24.4155 34.0162 24.7486 33.8857 25.6099C33.6201 27.219 32.9362 28.525 31.7868 29.7265C31.087 30.4796 30.2375 31.1345 29.2656 31.6107C28.7494 31.8818 28.1998 32.1164 27.6192 32.3059C23.2857 33.7212 18.85 32.1653 17.4201 28.8239C17.3061 28.5727 17.2095 28.3098 17.1335 28.0347C16.5241 25.8328 17.0414 23.1911 18.6584 21.5282C18.6585 21.528 18.6582 21.5273 18.6584 21.5273C18.758 21.4215 18.8598 21.2967 18.8598 21.1398C18.8598 21.0086 18.7764 20.8701 18.7041 20.7719C18.1383 19.9514 16.1787 18.5531 16.572 15.8472C16.8545 13.9031 18.5546 12.5341 20.1397 12.6152C20.2736 12.6222 20.4078 12.6303 20.5415 12.6382C21.2284 12.679 21.8276 12.7671 22.3931 12.7906C23.3395 12.8316 24.1906 12.6939 25.1986 11.8541C25.5386 11.5707 25.8112 11.3252 26.2725 11.247C26.321 11.2387 26.4416 11.1954 26.6827 11.2068C26.9287 11.2199 27.163 11.2875 27.3735 11.4276C28.1817 11.9654 28.2962 13.2677 28.3381 14.2205C28.362 14.7643 28.4279 16.0801 28.4502 16.4579C28.5017 17.3215 28.7287 17.4433 29.188 17.5945C29.4463 17.6797 29.6861 17.743 30.0395 17.8422C31.1092 18.1425 31.7435 18.4472 32.1431 18.8386C32.3816 19.0831 32.4925 19.3431 32.5268 19.5909C32.6528 20.5111 31.8123 21.6478 29.5872 22.6807C27.1549 23.8095 24.2041 24.0954 22.1653 23.8684C22.009 23.851 21.4529 23.788 21.451 23.7877C19.8201 23.5681 18.8899 25.6757 19.8686 27.1196C20.4995 28.0501 22.2176 28.6558 23.9367 28.6561C27.8783 28.6565 30.9078 26.9734 32.0347 25.5198C32.0685 25.4763 32.0718 25.4716 32.1249 25.3912C32.1803 25.3077 32.1347 25.2616 32.0656 25.3089C31.1448 25.9389 27.0552 28.4401 22.6808 27.6876C22.6808 27.6876 22.1493 27.6002 21.6641 27.4115C21.2785 27.2615 20.4715 26.8902 20.3734 26.0623C23.9036 27.154 26.1264 26.1219 26.1264 26.1219V26.1218ZM6.73637 17.7322C5.50864 17.971 4.42653 18.6668 3.76488 19.6279C3.36935 19.2981 2.63255 18.6595 2.50245 18.4107C1.44601 16.4049 3.65533 12.5048 5.19871 10.3023C9.01295 4.85925 14.9868 0.739281 17.7523 1.48684C18.2019 1.61408 19.6908 3.3404 19.6908 3.3404C19.6908 3.3404 16.9266 4.87423 14.363 7.01221C10.9088 9.6719 8.2995 13.5375 6.73637 17.7322ZM8.79942 26.937C8.61359 26.9687 8.42406 26.9814 8.23288 26.9767C6.38562 26.9272 4.39022 25.2641 4.19193 23.2919C3.97278 21.1119 5.08663 19.4342 7.05879 19.0364C7.29457 18.9889 7.57951 18.9615 7.88676 18.9775C8.99175 19.038 10.6201 19.8864 10.9921 22.2937C11.3216 24.4256 10.7983 26.5961 8.79942 26.937V26.937ZM33.8233 23.0768C33.8075 23.0209 33.7044 22.6441 33.5628 22.1901C33.4211 21.7358 33.2745 21.4162 33.2745 21.4162C33.8426 20.5656 33.8527 19.805 33.7772 19.374C33.6965 18.84 33.4742 18.3849 33.0261 17.9145C32.5779 17.4441 31.6614 16.9623 30.3733 16.6006C30.2261 16.5592 29.7403 16.4259 29.6976 16.413C29.6942 16.3851 29.662 14.8197 29.6328 14.1478C29.6114 13.662 29.5697 12.9036 29.3344 12.1566C29.054 11.1455 28.5653 10.2608 27.9555 9.69474C29.6385 7.95018 30.6892 6.02826 30.6867 4.37951C30.6818 1.20879 26.7878 0.24946 21.9891 2.23648C21.9841 2.23854 20.9797 2.66446 20.9724 2.66802C20.9678 2.66372 19.1343 0.864594 19.1067 0.84057C13.6355 -3.9316 -3.4707 15.0823 1.99847 19.7003L3.19371 20.7129C2.88368 21.516 2.76185 22.4362 2.86137 23.4258C2.9891 24.6967 3.64467 25.915 4.70726 26.8562C5.71596 27.75 7.04217 28.3156 8.32916 28.3145C10.4574 33.2191 15.3203 36.2279 21.0221 36.3972C27.1383 36.5789 32.2724 33.709 34.4238 28.5537C34.5645 28.1919 35.1617 26.5617 35.1617 25.1226C35.1617 23.6763 34.344 23.0768 33.8233 23.0768Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                        <.page_link path={"/"} class="flex justify-center items-center">
                            <svg class="h-6 hover:text-gray-900 dark:hover:text-white" viewBox="0 0 124 21" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M16.813 0.069519L12.5605 11.1781L8.28275 0.069519H0.96875V20.2025H6.23233V6.89245L11.4008 20.2025H13.7233L18.8634 6.89245V20.2025H24.127V0.069519H16.813Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M34.8015 16.461V15.1601C34.3138 14.4663 33.2105 14.1334 32.1756 14.1334C30.9504 14.1334 29.8174 14.679 29.8174 15.8245C29.8174 16.9699 30.9504 17.5155 32.1756 17.5155C33.2105 17.5155 34.3138 17.1533 34.8015 16.4595V16.461ZM34.8015 20.201V18.7519C33.8841 19.8358 32.1117 20.5633 30.213 20.5633C27.9484 20.5633 25.1367 19.0218 25.1367 15.7614C25.1367 12.2326 27.9469 11.0578 30.213 11.0578C32.1756 11.0578 33.9183 11.6885 34.8015 12.7767V11.3277C34.8015 10.0605 33.7042 9.18487 31.8039 9.18487C30.3349 9.18487 28.8658 9.75687 27.6748 10.7542L25.9322 7.52314C27.831 5.92447 30.3691 5.26007 32.6291 5.26007C36.1783 5.26007 39.5179 6.561 39.5179 11.0871V20.2025H34.8015V20.201Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M40.1562 18.3002L42.1145 14.9826C43.2178 15.9447 45.57 16.9421 47.3186 16.9421C48.7237 16.9421 49.3051 16.5461 49.3051 15.9154C49.3051 14.1055 40.7094 15.9741 40.7094 10.0605C40.7094 7.4938 42.9739 5.26007 47.0391 5.26007C49.5489 5.26007 51.6276 6.04474 53.22 7.1902L51.4194 10.4858C50.5303 9.6366 48.8471 8.88127 47.0747 8.88127C45.9715 8.88127 45.2384 9.30514 45.2384 9.8786C45.2384 11.4773 53.7999 9.81994 53.7999 15.7966C53.7999 18.5686 51.3257 20.5633 47.103 20.5633C44.4429 20.5633 41.7205 19.6862 40.1562 18.3002Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M64.7231 20.2025V11.7149C64.7231 9.94019 63.7759 9.36672 62.2712 9.36672C60.8958 9.36672 59.9784 10.1177 59.4313 10.7821V20.201H54.7148V0.069519H59.4313V7.40285C60.3145 6.37619 62.063 5.26152 64.5372 5.26152C67.9065 5.26152 69.4335 7.13299 69.4335 9.81992V20.2025H64.7231Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M80.0535 16.461V15.1601C79.5643 14.4663 78.4626 14.1334 77.4217 14.1334C76.1965 14.1334 75.0635 14.679 75.0635 15.8245C75.0635 16.9699 76.1965 17.5155 77.4217 17.5155C78.4626 17.5155 79.5643 17.1533 80.0535 16.4595V16.461ZM80.0535 20.201V18.7519C79.1346 19.8358 77.3578 20.5633 75.465 20.5633C73.199 20.5633 70.3828 19.0218 70.3828 15.7614C70.3828 12.2326 73.199 11.0578 75.465 11.0578C77.4217 11.0578 79.1644 11.6885 80.0535 12.7767V11.3277C80.0535 10.0605 78.9488 9.18487 77.056 9.18487C75.5869 9.18487 74.1164 9.75687 72.9209 10.7542L71.1783 7.52314C73.0771 5.92447 75.6152 5.26007 77.8812 5.26007C81.4289 5.26007 84.7625 6.561 84.7625 11.0871V20.2025H80.0535V20.201Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M93.8157 16.461C95.6802 16.461 97.0913 15.097 97.0913 12.897C97.0913 10.7263 95.6802 9.36232 93.8157 9.36232C92.8046 9.36232 91.5854 9.90645 90.9995 10.6911V15.1601C91.5854 15.9447 92.8061 16.461 93.8157 16.461ZM86.2891 20.201V0.069519H90.9995V7.34419C92.0485 6.01247 93.6688 5.2418 95.3784 5.26152C99.0778 5.26152 101.895 8.13032 101.895 12.897C101.895 17.847 99.0198 20.5633 95.3784 20.5633C93.7235 20.5633 92.2247 19.8989 90.9995 18.5114V20.2025H86.2891V20.201Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M102.844 0.069519H107.554V20.2025H102.844V0.069519Z" fill="currentColor"/>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M116.336 9.00154C114.284 9.00154 113.49 10.2101 113.303 11.2646H119.396C119.27 10.2379 118.508 9.00154 116.336 9.00154ZM108.5 12.897C108.5 8.67447 111.712 5.26007 116.336 5.26007C120.709 5.26007 123.892 8.42807 123.892 13.3781V14.4385H113.368C113.704 15.7335 114.929 16.8218 117.067 16.8218C118.108 16.8218 119.821 16.3686 120.681 15.5839L122.725 18.6317C121.26 19.9267 118.81 20.5633 116.55 20.5633C111.991 20.5633 108.5 17.6358 108.5 12.897Z" fill="currentColor"/>
                            </svg>
                        </.page_link>
                    </div>
                </div>
            </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_social_proof",
          description: "Renders an example of statistical numbers that you can use to showcase the adoption rate of your product by the community.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_social_proof",
          template: """
            <section class="bg-white dark:bg-gray-900">
              <div class="max-w-screen-xl px-4 py-8 mx-auto text-center lg:py-16 lg:px-6">
                  <dl class="grid max-w-screen-md gap-8 mx-auto text-gray-900 sm:grid-cols-3 dark:text-white">
                      <div class="flex flex-col items-center justify-center">
                          <dt class="mb-2 text-3xl md:text-4xl font-extrabold">73M+</dt>
                          <dd class="font-light text-gray-500 dark:text-gray-400">developers</dd>
                      </div>
                      <div class="flex flex-col items-center justify-center">
                          <dt class="mb-2 text-3xl md:text-4xl font-extrabold">1B+</dt>
                          <dd class="font-light text-gray-500 dark:text-gray-400">contributors</dd>
                      </div>
                      <div class="flex flex-col items-center justify-center">
                          <dt class="mb-2 text-3xl md:text-4xl font-extrabold">4M+</dt>
                          <dd class="font-light text-gray-500 dark:text-gray-400">organizations</dd>
                      </div>
                  </dl>
              </div>
            </section>
          """,
          example: """
            <section class="bg-white dark:bg-gray-900">
              <div class="max-w-screen-xl px-4 py-8 mx-auto text-center lg:py-16 lg:px-6">
                  <dl class="grid max-w-screen-md gap-8 mx-auto text-gray-900 sm:grid-cols-3 dark:text-white">
                      <div class="flex flex-col items-center justify-center">
                          <dt class="mb-2 text-3xl md:text-4xl font-extrabold">73M+</dt>
                          <dd class="font-light text-gray-500 dark:text-gray-400">developers</dd>
                      </div>
                      <div class="flex flex-col items-center justify-center">
                          <dt class="mb-2 text-3xl md:text-4xl font-extrabold">1B+</dt>
                          <dd class="font-light text-gray-500 dark:text-gray-400">contributors</dd>
                      </div>
                      <div class="flex flex-col items-center justify-center">
                          <dt class="mb-2 text-3xl md:text-4xl font-extrabold">4M+</dt>
                          <dd class="font-light text-gray-500 dark:text-gray-400">organizations</dd>
                      </div>
                  </dl>
              </div>
            </section>
          """,
          category: :section
        },
        %{
          name: "flowbite_faq",
          description: "Renders an example of a FAQ section to show a list of questions and answers based on two columns and a question mark icon.",
          thumbnail: "https://placehold.co/400x75?text=flowbite_faq",
          template: """
            <section class="bg-white dark:bg-gray-900">
              <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
                  <h2 class="mb-8 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">Frequently asked questions</h2>
                  <div class="grid pt-8 text-left border-t border-gray-200 md:gap-16 dark:border-gray-700 md:grid-cols-2">
                      <div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What do you mean by "Figma assets"?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">You will have access to download the full Figma project including all of the pages, the components, responsive pages, and also the icons, illustrations, and images included in the screens.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What does "lifetime access" exactly mean?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">Once you have purchased either the design, code, or both packages, you will have access to all of the future updates based on the roadmap, free of charge.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  How does support work?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">We're aware of the importance of well qualified support, that is why we decided that support will only be provided by the authors that actually worked on this project.</p>
                              <p class="text-gray-500 dark:text-gray-400">Feel free to <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline" target="_blank" rel="noreferrer">contact us</.page_link> and we'll help you out as soon as we can.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  I want to build more than one project. Is that allowed?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">You can use Windster for an unlimited amount of projects, whether it's a personal website, a SaaS app, or a website for a client. As long as you don't build a product that will directly compete with Windster either as a UI kit, theme, or template, it's fine.</p>
                              <p class="text-gray-500 dark:text-gray-400">Find out more information by <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">reading the license</.page_link>.</p>
                          </div>
                      </div>
                      <div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What does "free updates" include?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">The free updates that will be provided is based on the <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">roadmap</.page_link> that we have laid out for this project. It is also possible that we will provide extra updates outside of the roadmap as well.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What does the free version include?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">The <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">free version</.page_link> of Windster includes a minimal style guidelines, component variants, and a dashboard page with the mobile version alongside it.</p>
                              <p class="text-gray-500 dark:text-gray-400">You can use this version for any purposes, because it is open-source under the MIT license.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What is the difference between Windster and Tailwind UI?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">Although both Windster and Tailwind UI are built for integration with Tailwind CSS, the main difference is in the design, the pages, the extra components and UI elements that Windster includes.</p>
                              <p class="text-gray-500 dark:text-gray-400">Additionally, Windster is a project that is still in development, and later it will include both the application, marketing, and e-commerce UI interfaces.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  Can I use Windster in open-source projects?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">Generally, it is accepted to use Windster in open-source projects, as long as it is not a UI library, a theme, a template, a page-builder that would be considered as an alternative to Windster itself.</p>
                              <p class="text-gray-500 dark:text-gray-400">With that being said, feel free to use this design kit for your open-source projects.</p>
                              <p class="text-gray-500 dark:text-gray-400">Find out more information by <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">reading the license</.page_link>.</p>
                          </div>
                      </div>
                  </div>
              </div>
            </section>
          """,
          example: """
            <section class="bg-white dark:bg-gray-900">
              <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
                  <h2 class="mb-8 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white">Frequently asked questions</h2>
                  <div class="grid pt-8 text-left border-t border-gray-200 md:gap-16 dark:border-gray-700 md:grid-cols-2">
                      <div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What do you mean by "Figma assets"?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">You will have access to download the full Figma project including all of the pages, the components, responsive pages, and also the icons, illustrations, and images included in the screens.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What does "lifetime access" exactly mean?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">Once you have purchased either the design, code, or both packages, you will have access to all of the future updates based on the roadmap, free of charge.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  How does support work?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">We're aware of the importance of well qualified support, that is why we decided that support will only be provided by the authors that actually worked on this project.</p>
                              <p class="text-gray-500 dark:text-gray-400">Feel free to <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline" target="_blank" rel="noreferrer">contact us</.page_link> and we'll help you out as soon as we can.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  I want to build more than one project. Is that allowed?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">You can use Windster for an unlimited amount of projects, whether it's a personal website, a SaaS app, or a website for a client. As long as you don't build a product that will directly compete with Windster either as a UI kit, theme, or template, it's fine.</p>
                              <p class="text-gray-500 dark:text-gray-400">Find out more information by <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">reading the license</.page_link>.</p>
                          </div>
                      </div>
                      <div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What does "free updates" include?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">The free updates that will be provided is based on the <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">roadmap</.page_link> that we have laid out for this project. It is also possible that we will provide extra updates outside of the roadmap as well.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What does the free version include?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">The <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">free version</.page_link> of Windster includes a minimal style guidelines, component variants, and a dashboard page with the mobile version alongside it.</p>
                              <p class="text-gray-500 dark:text-gray-400">You can use this version for any purposes, because it is open-source under the MIT license.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  What is the difference between Windster and Tailwind UI?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">Although both Windster and Tailwind UI are built for integration with Tailwind CSS, the main difference is in the design, the pages, the extra components and UI elements that Windster includes.</p>
                              <p class="text-gray-500 dark:text-gray-400">Additionally, Windster is a project that is still in development, and later it will include both the application, marketing, and e-commerce UI interfaces.</p>
                          </div>
                          <div class="mb-10">
                              <h3 class="flex items-center mb-4 text-lg font-medium text-gray-900 dark:text-white">
                                  <svg class="flex-shrink-0 mr-2 w-5 h-5 text-gray-500 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                                  Can I use Windster in open-source projects?
                              </h3>
                              <p class="text-gray-500 dark:text-gray-400">Generally, it is accepted to use Windster in open-source projects, as long as it is not a UI library, a theme, a template, a page-builder that would be considered as an alternative to Windster itself.</p>
                              <p class="text-gray-500 dark:text-gray-400">With that being said, feel free to use this design kit for your open-source projects.</p>
                              <p class="text-gray-500 dark:text-gray-400">Find out more information by <.page_link path={"/"} class="font-medium underline text-primary-600 dark:text-primary-500 hover:no-underline">reading the license</.page_link>.</p>
                          </div>
                      </div>
                  </div>
              </div>
            </section>
          """,
          category: :section
        }
      ]

    dynamic_tag =
      if Version.compare(Beacon.Private.phoenix_live_view_version(), "1.0.0-rc.7") in [:eq, :gt] do
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
          template: ~S|<.dynamic_tag tag_name={@name} class={@class}><%= render_slot(@inner_block) %></.dynamic_tag>|,
          example: ~S|<.html_tag name="p" class="text-xl">content</.tag>|,
          category: :element
        }
      else
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
        }
      end

    [dynamic_tag | components]
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

  Returns `{:ok, component}` if successful, otherwise `{:error, changeset}`.

  ## Example

      iex> create_component(attrs)
      {:ok, %Component{}}

  """
  @spec create_component(map()) :: {:ok, Component.t()} | {:error, Changeset.t()}
  @doc type: :components
  def create_component(attrs \\ %{}) do
    changeset = Component.changeset(%Component{}, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> validate_component_template()
    |> repo(site).insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :component))
  end

  @doc """
  Creates a component, raising an error if unsuccessful.

  Returns the new component if successful, otherwise raises a `RuntimeError`.
  """
  @doc type: :components
  @spec create_component!(map()) :: Component.t()
  def create_component!(attrs \\ %{}) do
    case create_component(attrs) do
      {:ok, component} ->
        component

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        raise "failed to create component: #{inspect(errors)}"
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
    |> repo(component).update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :component))
  end

  defp validate_component_template(changeset) do
    site = Changeset.get_field(changeset, :site)
    template = Changeset.get_field(changeset, :template)
    metadata = %Beacon.Template.LoadMetadata{site: site, path: "nopath"}
    do_validate_template(changeset, :template, :heex, template, metadata)
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
    preloads = Keyword.get(opts, :preloads, [])

    preloads =
      Enum.reduce(preloads, [], fn
        :attrs, acc ->
          attrs_query = from ca in ComponentAttr, order_by: [asc: ca.name]
          [{:attrs, attrs_query} | acc]

        :slots, acc ->
          slots_query = from ca in ComponentSlot, order_by: [asc: ca.name]
          [{:slots, slots_query} | acc]

        {:slots, :attrs}, acc ->
          slots_query = from ca in ComponentSlot, order_by: [asc: ca.name]
          [{:slots, {slots_query, [:attrs]}} | acc]
      end)

    Component
    |> repo(site).get_by(clauses)
    |> repo(site).preload(preloads)
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
    repo(site).all(
      from c in Component,
        where: c.site == ^site and c.name == ^name
    )
  end

  @doc """
  List components.

  ## Options

    * `:per_page` - limit how many records are returned, or pass `:infinity` to return all records. Defaults to 20.
    * `:page` - returns records from a specific page. Defaults to 1.
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
    |> repo(site).all()
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
    |> repo(site).one()
  end

  # COMPONENT ATTR

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking component_attr changes.

  ## Example

      iex> change_component_attr(component_attr, %{name: "Header"})
      %Ecto.Changeset{data: %ComponentAttr{}}

      iex> change_component_attr(component_attr, %{name: "Header"}, ["sites", ["pages"]])
      %Ecto.Changeset{data: %ComponentAttr{}}

  """
  @doc type: :components
  @spec change_component_attr(ComponentAttr.t(), map(), list(String.t())) :: Changeset.t()
  def change_component_attr(%ComponentAttr{} = component_attr, attrs, component_attr_names) do
    ComponentAttr.changeset(component_attr, attrs, component_attr_names)
  end

  # COMPONENT SLOTS

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking slot changes.

  ## Example

      iex> change_component_slot(component_slot, %{name: "slot_a"}, ["slot_name_1])
      %Ecto.Changeset{data: %ComponentSlot{}}

  """
  @doc type: :components
  @spec change_component_slot(ComponentSlot.t(), map(), list(String.t())) :: Changeset.t()
  def change_component_slot(%ComponentSlot{} = slot, attrs, component_slots_names) do
    ComponentSlot.changeset(slot, attrs, component_slots_names)
  end

  @doc """
  Creates a new component slot and returns the component with updated `:slots` association.
  """
  @doc type: :components
  @spec create_slot_for_component(Component.t(), %{name: binary()}) ::
          {:ok, Component.t()} | {:error, Changeset.t()}
  def create_slot_for_component(component, attrs) do
    changeset =
      component
      |> Ecto.build_assoc(:slots)
      |> ComponentSlot.changeset(attrs)

    with {:ok, %ComponentSlot{}} <- repo(component).insert(changeset),
         %Component{} = component <- repo(component).preload(component, [slots: [:attrs]], force: true) do
      {:ok, component}
    end
  end

  @doc """
  Updates a component slot and returns the component with updated `:slots` association.
  """
  @doc type: :components
  @spec update_slot_for_component(Component.t(), ComponentSlot.t(), map(), list(String.t())) :: {:ok, Component.t()} | {:error, Changeset.t()}
  def update_slot_for_component(component, slot, attrs, component_slots_names) do
    changeset = ComponentSlot.changeset(slot, attrs, component_slots_names)

    with {:ok, %ComponentSlot{}} <- repo(component).update(changeset),
         %Component{} = component <- repo(component).preload(component, [slots: [:attrs]], force: true) do
      {:ok, component}
    end
  end

  @doc """
  Deletes a component slot and returns the component with updated slots association.
  """
  @doc type: :components
  @spec delete_slot_from_component(Component.t(), ComponentSlot.t()) :: {:ok, Component.t()} | {:error, Changeset.t()}
  def delete_slot_from_component(component, slot) do
    with {:ok, %ComponentSlot{}} <- repo(component).delete(slot),
         %Component{} = component <- repo(component).preload(component, [slots: [:attrs]], force: true) do
      {:ok, component}
    end
  end

  @doc false
  def validate_if_value_matches_type(changeset, type, value, field) do
    cond do
      value == nil -> changeset
      type == "any" or type == "global" -> changeset
      type == "string" and is_binary(value) -> changeset
      type == "string" -> Changeset.add_error(changeset, field, "it must be a string when type is 'string'")
      type == "atom" and is_atom(value) -> changeset
      type == "atom" -> Changeset.add_error(changeset, field, "it must be an atom when type is 'atom'")
      type == "boolean" and is_boolean(value) -> changeset
      type == "boolean" -> Changeset.add_error(changeset, field, "it must be a boolean when type is 'boolean'")
      type == "integer" and is_integer(value) -> changeset
      type == "integer" -> Changeset.add_error(changeset, field, "it must be a integer when type is 'integer'")
      type == "float" and is_float(value) -> changeset
      type == "float" -> Changeset.add_error(changeset, field, "it must be a float when type is 'float'")
      type == "list" and is_list(value) -> changeset
      type == "list" -> Changeset.add_error(changeset, field, "it must be a list when type is 'list'")
      type == "map" and is_map(value) -> changeset
      type == "map" -> Changeset.add_error(changeset, field, "it must be a map when type is 'map'")
      type == "struct" and is_struct(value) -> changeset
      type == "struct" -> Changeset.add_error(changeset, field, "it must be a struct when type is 'struct'")
    end
  end

  # COMPONENT SLOT ATTR

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking slot_attr changes.

  ## Example

      iex> change_slot_attr(slot_attr, %{name: "Header"}, [])
      %Ecto.Changeset{data: %ComponentSlotAttr{}}

  """
  @doc type: :components
  @spec change_slot_attr(ComponentSlotAttr.t(), map(), list(String.t())) :: Changeset.t()
  def change_slot_attr(%ComponentSlotAttr{} = slot_attr, attrs, slot_attr_names) do
    ComponentSlotAttr.changeset(slot_attr, attrs, slot_attr_names)
  end

  @doc """
  Creates a slot attr.

  ## Example

      iex> create_slot_attr(site, attrs)
      {:ok, %ComponentSlotAttr{}}

  """
  @spec create_slot_attr(Site.t(), map(), list(String.t())) :: {:ok, ComponentSlotAttr.t()} | {:error, Changeset.t()}
  @doc type: :components
  def create_slot_attr(site, attrs, slot_attr_names) do
    %ComponentSlotAttr{}
    |> ComponentSlotAttr.changeset(attrs, slot_attr_names)
    |> repo(site).insert()
  end

  @doc """
  Updates a slot attr.

      iex> update_slot(slot_attr, %{name: "new_slot"})
      {:ok, %ComponentSlotAttr{}}

  """
  @doc type: :components
  @spec update_slot_attr(Site.t(), ComponentSlotAttr.t(), map(), list(String.t())) :: {:ok, ComponentAttr.t()} | {:error, Changeset.t()}
  def update_slot_attr(site, %ComponentSlotAttr{} = slot_attr, attrs, slot_attr_names) do
    slot_attr
    |> ComponentSlotAttr.changeset(attrs, slot_attr_names)
    |> repo(site).update()
  end

  @doc """
  Deletes a slot attr.
  """
  @doc type: :components
  @spec delete_slot_attr(Site.t(), ComponentSlotAttr.t()) :: {:ok, ComponentSlotAttr.t()} | {:error, Changeset.t()}
  def delete_slot_attr(site, slot_attr) do
    repo(site).delete(slot_attr)
  end

  # SNIPPETS

  @doc """
  Creates a snippet helper.

  Returns `{:ok, helper}` if successful, otherwise `{:error, changeset}`
  """
  @doc type: :snippets
  @spec create_snippet_helper(map()) :: {:ok, Snippets.Helper.t()} | {:error, Changeset.t()}
  def create_snippet_helper(attrs) do
    changeset =
      %Snippets.Helper{}
      |> Changeset.cast(attrs, [:site, :name, :body])
      |> Changeset.validate_required([:site, :name, :body])
      |> Changeset.unique_constraint([:site, :name])

    site = Changeset.get_field(changeset, :site)

    changeset
    |> validate_snippet_helper()
    |> repo(site).insert()
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

  @doc """
  Creates a snippet helper, raising an error if unsuccessful.

  Returns the new helper if successful, otherwise raises a `RuntimeError`.
  """
  @doc type: :snippets
  @spec create_snippet_helper!(map()) :: Snippets.Helper.t()
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
    repo(site).all(from h in Snippets.Helper, where: h.site == ^site)
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
    repo(site).one(
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
    |> repo(site).all()
  end

  @doc """
  Lists all error pages for a given site, filtered by `clauses`.

  Currently the only acceptable clause is `:layout_id`.
  See `list_error_pages/2` for a list of acceptable `opts`.
  """
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
    |> repo(site).all()
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
    changeset = ErrorPage.changeset(%ErrorPage{}, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> validate_error_page()
    |> repo(site).insert()
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
    |> repo(error_page).update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :error_page))
  end

  @doc """
  Deletes an error page.
  """
  @doc type: :error_pages
  @spec delete_error_page(ErrorPage.t()) :: {:ok, ErrorPage.t()} | {:error, Changeset.t()}
  def delete_error_page(error_page) do
    repo(error_page).delete(error_page)
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

      iex> change_event_handler(event_handler, %{name: "form-submit"})
      %Ecto.Changeset{data: %EventHandler{}}

  """
  @doc type: :event_handlers
  @spec change_event_handler(EventHandler.t(), map()) :: Changeset.t()
  def change_event_handler(%EventHandler{} = event_handler, attrs \\ %{}) do
    EventHandler.changeset(event_handler, attrs)
  end

  @doc """
  Lists all event handlers for a given Beacon site.
  """
  @doc type: :event_handlers
  @spec list_event_handlers(Site.t()) :: [EventHandler.t()]
  def list_event_handlers(site) do
    repo(site).all(from eh in EventHandler, where: [site: ^site])
  end

  @doc """
  Creates a new event handler.
  """
  @doc type: :event_handlers
  @spec create_event_handler(%{name: binary(), code: binary(), site: Site.t()}) ::
          {:ok, EventHandler.t()} | {:error, Changeset.t()}
  def create_event_handler(attrs) do
    changeset =
      %EventHandler{}
      |> EventHandler.changeset(attrs)
      |> validate_event_handler()

    site = Changeset.get_field(changeset, :site)

    changeset
    |> repo(site).insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :event_handler))
  end

  @doc """
  Creates an event handler, raising an error if unsuccessful.
  """
  @doc type: :event_handlers
  @spec create_event_handler!(map()) :: EventHandler.t()
  def create_event_handler!(attrs \\ %{}) do
    case create_event_handler(attrs) do
      {:ok, event_handler} ->
        event_handler

      {:error, changeset} ->
        raise "failed to create event_handler: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates an event handler with the given attrs.
  """
  @doc type: :event_handlers
  @spec update_event_handler(EventHandler.t(), map()) :: {:ok, EventHandler.t()} | {:error, Changeset.t()}
  def update_event_handler(event_handler, attrs) do
    event_handler
    |> EventHandler.changeset(attrs)
    |> validate_event_handler()
    |> repo(event_handler).update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :event_handler))
  end

  defp validate_event_handler(changeset) do
    code = Changeset.get_field(changeset, :code)
    variable_names = ["socket", "event_params"]
    imports = ["Phoenix.Socket"]

    do_validate_template(changeset, :code, :elixir, code, nil, variable_names, imports)
  end

  @doc """
  Deletes an event handler.
  """
  @doc type: :event_handlers
  @spec delete_event_handler(EventHandler.t()) :: {:ok, EventHandler.t()} | {:error, Changeset.t()}
  def delete_event_handler(event_handler) do
    event_handler
    |> repo(event_handler).delete()
    |> tap(&maybe_broadcast_updated_content_event(&1, :event_handler))
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

    transact(repo(page), fn ->
      with {:ok, %PageVariant{}} <- repo(page).insert(changeset),
           %Page{} = page <- repo(page).preload(page, :variants, force: true),
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

    transact(repo(page), fn ->
      with {:ok, %PageVariant{}} <- repo(page).update(changeset),
           %Page{} = page <- repo(page).preload(page, :variants, force: true),
           %Page{} = page <- Lifecycle.Page.after_update_page(page) do
        {:ok, page}
      end
    end)
  end

  defp validate_variant(changeset, page) do
    %{format: format, site: site, path: path} = page = repo(page).preload(page, :variants)
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
  Deletes a page variant and returns the page with updated `:variants` association.
  """
  @doc type: :page_variants
  @spec delete_variant_from_page(Page.t(), PageVariant.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def delete_variant_from_page(page, variant) do
    with {:ok, %PageVariant{}} <- repo(page).delete(variant),
         %Page{} = page <- repo(page).preload(page, :variants, force: true),
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

  Returns `{:ok, live_data}` if successful, otherwise `{:error, changeset}`
  """
  @doc type: :live_data
  @spec create_live_data(map()) :: {:ok, LiveData.t()} | {:error, Changeset.t()}
  def create_live_data(attrs) do
    changeset = LiveData.changeset(%LiveData{}, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> repo(site).insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :live_data))
  end

  @doc """
  Creates a new LiveData for scoping live data to pages, raising an error if unsuccessful.

  Returns the new LiveData if successful, otherwise raises a `RuntimeError`.
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

    case repo(live_data).insert(changeset) do
      {:ok, %LiveDataAssign{}} ->
        live_data = repo(live_data).preload(live_data, :assigns, force: true)
        maybe_broadcast_updated_content_event({:ok, live_data}, :live_data)
        {:ok, live_data}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a single live data by `clauses`.

  ## Example

      iex> get_live_data_by(site, id: "cba9ee2e-d40e-48af-9704-1237e4c23bde")
      %LiveData{}

      iex> get_live_data_by(site, path: "/blog")
      %LiveData{}

  """
  @doc type: :live_data
  @spec get_live_data_by(Site.t(), keyword(), keyword()) :: LiveData.t() | nil
  def get_live_data_by(site, clauses, opts \\ []) when is_atom(site) and is_list(clauses) do
    clauses = Keyword.put(clauses, :site, site)
    repo(site).get_by(LiveData, clauses, opts) |> repo(site).preload(:assigns)
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
    |> repo(site).all()
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
    |> repo(live_data).update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :live_data))
  end

  @doc """
  Updates LiveDataAssign.

      iex> update_live_data_assign(live_data_assign, :my_site, %{code: "true"})
      {:ok, %LiveDataAssign{}}

  """
  @doc type: :live_data
  @spec update_live_data_assign(LiveDataAssign.t(), Site.t(), map()) :: {:ok, LiveDataAssign.t()} | {:error, Changeset.t()}
  def update_live_data_assign(%LiveDataAssign{} = live_data_assign, site, attrs) do
    live_data_assign
    |> repo(site).preload(:live_data)
    |> LiveDataAssign.changeset(attrs)
    |> validate_live_data_code()
    |> repo(site).update()
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
    repo(live_data).delete(live_data)
  end

  @doc """
  Deletes LiveDataAssign.
  """
  @doc type: :live_data
  @spec delete_live_data_assign(LiveDataAssign.t(), Site.t()) :: {:ok, LiveDataAssign.t()} | {:error, Changeset.t()}
  def delete_live_data_assign(live_data_assign, site) do
    repo(site).delete(live_data_assign)
  end

  @doc """
  Creates a new info handler for creating shared handle_info callbacks.

  ## Example

      iex> create_info_handler(%{site: "my_site", msg: "{:new_msg, arg}", code: "{:noreply, socket}"})
      {:ok, %InfoHandler{}}

  """
  @doc type: :info_handlers
  @spec create_info_handler(map()) :: {:ok, InfoHandler.t()} | {:error, Changeset.t()}
  def create_info_handler(attrs) do
    changeset = InfoHandler.changeset(%InfoHandler{}, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> validate_info_handler()
    |> repo(site).insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :info_handler))
  end

  @spec validate_info_handler(Changeset.t(), [String.t()]) :: Changeset.t()
  defp validate_info_handler(changeset, imports \\ []) do
    code = Changeset.get_field(changeset, :code)
    msg = Changeset.get_field(changeset, :msg)
    site = Changeset.get_field(changeset, :site)
    metadata = %Beacon.Template.LoadMetadata{site: site}
    var = ["socket", msg]
    imports = ["Phoenix.LiveView"] ++ imports

    do_validate_template(changeset, :code, :elixir, code, metadata, var, imports)
  end

  @doc """
  Creates a info handler, raising an error if unsuccessful.

  Returns the new info handler if successful, otherwise raises a `RuntimeError`.

  ## Example

      iex> create_info_handler!(%{site: "my_site", msg: "{:new_msg, arg}", code: "{:noreply, socket}"})
      %InfoHandler{}
  """
  @doc type: :info_handlers
  @spec create_info_handler!(map()) :: InfoHandler.t()
  def create_info_handler!(attrs \\ %{}) do
    case create_info_handler(attrs) do
      {:ok, info_handler} -> info_handler
      {:error, changeset} -> raise "failed to create info handler, got: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking info handler changes.

  ## Example

      iex> change_info_handler(info_handler, %{code: {:noreply, socket}})
      %Ecto.Changeset{data: %InfoHandler{}}

  """
  @doc type: :info_handlers
  @spec change_info_handler(InfoHandler.t(), map()) :: Changeset.t()
  def change_info_handler(%InfoHandler{} = info_handler, attrs \\ %{}) do
    InfoHandler.changeset(info_handler, attrs)
  end

  @doc """
  Gets a single info handler by `id`.

  ## Example

      iex> get_single_info_handler(:my_site, "fefebbfe-f732-4119-9116-d031d04f5a2c")
      %InfoHandler{}

  """
  @doc type: :info_handlers
  @spec get_info_handler(Site.t(), UUID.t()) :: InfoHandler.t() | nil
  def get_info_handler(site, id) when is_atom(site) and is_binary(id) do
    repo(site).get(InfoHandler, id)
  end

  @doc """
  Same as `get_info_handler/2` but raises an error if no result is found.
  """
  @doc type: :info_handlers
  @spec get_info_handler!(Site.t(), UUID.t()) :: InfoHandler.t()
  def get_info_handler!(site, id) when is_atom(site) and is_binary(id) do
    repo(site).get!(InfoHandler, id)
  end

  @doc """
  Lists all info handlers for a given site.

  ## Example

      iex> list_info_handlers()

  """
  @doc type: :info_handlers
  @spec list_info_handlers(Site.t()) :: [InfoHandler.t()]
  def list_info_handlers(site) do
    repo(site).all(
      from h in InfoHandler,
        where: h.site == ^site,
        order_by: [asc: h.inserted_at]
    )
  end

  @doc """
  Updates a info handler.

  ## Example

      iex> update_info_handler(info_handler, %{msg: "{:new_msg, arg}"})
      {:ok, %InfoHandler{}}

  """
  @doc type: :info_handlers
  @spec update_info_handler(InfoHandler.t(), map()) :: {:ok, InfoHandler.t()}
  def update_info_handler(%InfoHandler{} = info_handler, attrs) do
    changeset = InfoHandler.changeset(info_handler, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> validate_info_handler(["Phoenix.Component"])
    |> repo(site).update()
    |> tap(&maybe_broadcast_updated_content_event(&1, :info_handler))
  end

  @doc """
  Deletes info handler.
  """
  @doc type: :info_handlers
  @spec delete_info_handler(InfoHandler.t()) :: {:ok, InfoHandler.t()} | {:error, Changeset.t()}
  def delete_info_handler(info_handler) do
    info_handler
    |> repo(info_handler).delete()
    |> tap(&maybe_broadcast_updated_content_event(&1, :info_handler))
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
    case insert_published_page(page) do
      {:ok, page} ->
        :ok = Beacon.PubSub.page_published(page)
        {:reply, {:ok, page}, config}

      error ->
        {:reply, error, config}
    end
  end

  @doc false
  def handle_call({:unpublish_page, page}, _from, config) do
    case insert_unpublished_page(page) do
      {:ok, page} ->
        :ok = Beacon.PubSub.page_unpublished(page)
        {:reply, {:ok, page}, config}

      error ->
        {:reply, error, config}
    end
  end

  @doc false
  def handle_call({:publish_layout, layout}, _from, config) do
    case do_publish_layout(layout) do
      {:ok, layout} -> {:reply, {:ok, layout}, config}
      {:error, error} -> {:reply, error, config}
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

  defp insert_published_layout(layout) do
    %{site: site} = layout

    changeset = Layout.changeset(layout, %{})

    transact(repo(site), fn ->
      with {:ok, _changeset} <- validate_layout_template(changeset),
           {:ok, event} <- create_layout_event(layout, "published"),
           {:ok, _snapshot} <- create_layout_snapshot(layout, event) do
        {:ok, layout}
      end
    end)
  end

  defp insert_published_page(page) do
    %{site: site} = page
    changeset = Page.update_changeset(page, %{})

    transact(repo(site), fn ->
      with {:ok, _changeset} <- validate_page_template(changeset),
           {:ok, event} <- create_page_event(page, "published"),
           {:ok, _snapshot} <- create_page_snapshot(page, event),
           %Page{} = page <- Lifecycle.Page.after_publish_page(page) do
        {:ok, page}
      end
    end)
  end

  defp insert_unpublished_page(page) do
    transact(repo(page), fn ->
      with {:ok, _event} <- create_page_event(page, "unpublished"),
           %Page{} = page <- Lifecycle.Page.after_unpublish_page(page) do
        {:ok, page}
      end
    end)
  end

  @doc false
  def reset_published_layout(site, id) do
    clear_cache(site, id)
    :ok
  end

  @doc false
  def reset_published_page(site, id) do
    clear_cache(site, id)

    case get_published_page(site, id) do
      nil -> :skip
      page -> :ok = Beacon.RouterServer.add_page(page.site, page.id, page.path)
    end

    :ok
  end

  defp do_publish_layout(layout) do
    %{site: site} = layout

    publish = fn layout ->
      changeset = Layout.changeset(layout, %{})

      transact(repo(site), fn ->
        with {:ok, _changeset} <- validate_layout_template(changeset),
             {:ok, event} <- create_layout_event(layout, "published"),
             {:ok, _snapshot} <- create_layout_snapshot(layout, event) do
          {:ok, layout}
        end
      end)
    end

    with {:ok, layout} <- publish.(layout),
         :ok <- Beacon.PubSub.layout_published(layout) do
      {:ok, layout}
    else
      error -> error
    end
  end

  @doc false
  def handle_info(msg, config) do
    Logger.warning("Beacon.Content can not handle the message: #{inspect(msg)}")
    {:noreply, config}
  end
end
