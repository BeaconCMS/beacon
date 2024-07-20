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
  use GenServer

  import Ecto.Query
  import Beacon.Utils, only: [repo: 1, transact: 2]

  alias Beacon.Content.Component
  alias Beacon.Content.ComponentAttr
  alias Beacon.Content.ComponentSlot
  alias Beacon.Content.ComponentSlotAttr
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
  alias Beacon.Template.HEEx.HEExDecoder
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
  @spec publish_layout(Site.t(), UUID.t()) :: {:ok, Layout.t()} | any()
  def publish_layout(site, id) when is_atom(site) and is_binary(id) do
    site
    |> get_layout(id)
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
    {ast, attrs} = Map.pop(attrs, "ast")

    attrs =
      if is_nil(ast) do
        attrs
      else
        Map.put(attrs, :template, HEExDecoder.decode(ast))
      end

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
    GenServer.call(name(page.site), {:publish_page, page})
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

  Note that page will be removed from your site
  and it will return error 404 for new requests.
  """
  @doc type: :pages
  @spec unpublish_page(Page.t()) :: {:ok, Page.t()} | {:error, Changeset.t()}
  def unpublish_page(%Page{} = page) do
    transact(repo(page), fn ->
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
    |> repo(page).insert()
  end

  @doc false
  def create_page_snapshot(page, event) do
    page = repo(page).preload(page, [:variants, :event_handlers])

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
    |> repo(page).preload([:variants, :event_handlers], force: true)
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(%{schema_version: 2, page: %Page{} = page}) do
    page
    |> repo(page).reload()
    |> repo(page).preload([:variants, :event_handlers], force: true)
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

  # STYLESHEETS

  @doc """
  Creates a stylesheet.

  Returns `{:ok, stylesheet}` if successful, otherwise `{:error, changeset}`.

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
    changeset = Stylesheet.changeset(%Stylesheet{}, attrs)
    site = Changeset.get_field(changeset, :site)

    changeset
    |> repo(site).insert()
    |> tap(&maybe_broadcast_updated_content_event(&1, :stylesheet))
  end

  @doc """
  Creates a stylesheet.

  Returns the new stylesheet if successful, otherwise raises an error.

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
      %Stylesheet{}

  Note that escape characters must be preserved, so you should use `~S` to avoid issues.
  """
  @doc type: :stylesheets
  @spec create_stylesheet(map()) :: Stylesheet.t()
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
        example: ~S|<.page_link path={~p"/contact"} class="text-xl">Contact Us</.page_link>|,
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
        template: ~S|
        <button
          type={@type}
          class="phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80",
          {@rest}
        >
          <%= render_slot(@inner_block) %>
        </button>
        |,
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
        template: ~S|
        <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
          <%= render_slot(@inner_block) %>
        </p>
        |,
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
        template: ~S|
        <.form :let={f} for={@for} as={@as} {@rest}>
          <div class="mt-10 space-y-8 bg-white">
            <%= render_slot(@inner_block, f) %>
            <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
              <%= render_slot(action, f) %>
            </div>
          </div>
        </.form>
        |,
        example: ~S|
        <.simple_form :let={f} for={%{}} as={:newsletter} phx-submit="join">
          <.input field={f[:name]} label="Name"/>
          <.input field={f[:email]} label="Email"/>
          <:actions>
            <.button>Join</.button>
          </:actions>
        </.simple_form>
        |,
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
        body: ~S"""
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
        """,
        template: ~S"""
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
        """,
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
        template: ~S|
        <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
          <%= render_slot(@inner_block) %>
        </label>
        |,
        example: ~S|
        <.label for={"newsletter_email"}>
          Email
        </.label>
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
      },
      %{
        name: "flowbite_cta",
        description: "Renders a simple heading, paragraph, and a couple of CTA buttons to encourage users to take action.",
        thumbnail: "https://placehold.co/400x75?text=flowbite_cta",
        attrs: [
          %{name: "heading", type: "string", opts: [required: true]},
          %{name: "paragraph", type: "string", opts: [default: nil]}
        ],
        slots: [
          %{name: "actions"}
        ],
        template: """
        <section class="bg-white dark:bg-gray-900">
          <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
              <div class="max-w-screen-md">
                  <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white"><%= @heading %></h2>
                  <p :if={@paragraph} class="mb-8 font-light text-gray-500 sm:text-xl dark:text-gray-400"><%= @paragraph %></p>
                  <div :for={action <- @actions} class="flex flex-col space-y-4 sm:flex-row sm:space-y-0 sm:space-x-4">
                      <%= render_slot(action) %>
                  </div>
              </div>
          </div>
        </section>
        """,
        example: """
        <.flowbite_cta
          heading="Let's find more that brings us together."
          paragraph="Flowbite helps you connect with friends, family and communities of people who share your interests. Connecting with your friends and family as well as discovering new ones is easy with features like Groups, Watch and Marketplace."
        >
          <:actions>
            <.link href="#" class="inline-flex items-center justify-center px-4 py-2.5 text-base font-medium text-center text-white bg-neutral-700 rounded-lg hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
              Get started
            </.link>
            <.link href="#" class="inline-flex items-center justify-center px-4 py-2.5 text-base font-medium text-center text-gray-900 border border-gray-300 rounded-lg hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:focus:ring-gray-600">
              <svg class="mr-2 -ml-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"></path></svg>
              View more
            </.link>
          </:actions>
        </.flowbite_cta>
        """,
        category: :section
      },
      %{
        name: "flowbite_cta_with_image",
        description: "Renders an image or app screenshot next to the CTA button to provide additional visual impact.",
        thumbnail: "https://placehold.co/400x75?text=flowbite_cta_with_image",
        attrs: [
          %{name: "heading", type: "string", opts: [required: true]},
          %{name: "paragraph", type: "string", opts: [default: nil]}
        ],
        slots: [
          %{name: "action"}
        ],
        template: """
        <section class="bg-white dark:bg-gray-900">
          <div class="gap-8 items-center py-8 px-4 mx-auto max-w-screen-xl xl:gap-16 md:grid md:grid-cols-2 sm:py-16 lg:px-6">
            <img class="w-full dark:hidden" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/cta/cta-dashboard-mockup.svg" alt="dashboard image">
            <img class="w-full hidden dark:block" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/cta/cta-dashboard-mockup-dark.svg" alt="dashboard image">
            <div class="mt-4 md:mt-0">
              <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white"><%= @heading %></h2>
              <p class="mb-6 font-light text-gray-500 md:text-lg dark:text-gray-400"><%= @paragraph %></p>
              <%= render_slot(@action) %>
            </div>
          </div>
        </section>
        """,
        example: """
        <.flowbite_cta_with_image
          heading="Let's create more tools and ideas that brings us together."
          paragraph="Flowbite helps you connect with friends and communities of people who share your interests. Connecting with your friends and family as well as discovering new ones is easy with features like Groups."
        >
          <:action>
            <.link href="#" class="inline-flex items-center text-white bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:focus:ring-neutral-900">
              Get started
              <svg class="ml-2 -mr-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path>
              </svg>
            </.link>
          </:action>
        </.flowbite_cta_with_image>
        """,
        category: :section
      },
      %{
        name: "flowbite_cta_centered",
        description: "Renders CTA section with a heading, short paragraph, and a button to encourage users to start a free trial.",
        thumbnail: "https://placehold.co/400x75?text=flowbite_cta_centered",
        attrs: [
          %{name: "heading", type: "string", opts: [required: true]},
          %{name: "paragraph", type: "string", opts: [default: nil]}
        ],
        slots: [
          %{name: "action"}
        ],
        template: """
        <section class="bg-white dark:bg-gray-900">
          <div class="py-8 px-4 mx-auto max-w-screen-xl sm:py-16 lg:px-6">
            <div class="mx-auto max-w-screen-sm text-center">
              <h2 class="mb-4 text-4xl tracking-tight font-extrabold leading-tight text-gray-900 dark:text-white"><%= @heading %></h2>
              <p class="mb-6 font-light text-gray-500 dark:text-gray-400 md:text-lg"><%= @paragraph %></p>
              <%= render_slot(@action) %>
            </div>
          </div>
        </section>
        """,
        example: """
        <.flowbite_cta_centered
          heading="Start your free trial today"
          paragraph="Try Flowbite Platform for 30 days. No credit card required."
        >
          <:action>
            <a href="#" class="text-white bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 font-medium rounded-lg text-sm px-5 py-2.5 mr-2 mb-2 dark:bg-neutral-600 dark:hover:bg-neutral-700 focus:outline-none dark:focus:ring-neutral-800">Free trial for 30 days</a>
          </:action>
        </.flowbite_cta_centered>
        """,
        category: :section
      },
      %{
        name: "flowbite_hero",
        description: "Renders an announcement badge, heading, CTA buttons, and customer logos to showcase what your website offers.",
        thumbnail: "https://placehold.co/400x75?text=flowbite_hero",
        attrs: [
          %{name: "heading", type: "string", opts: [required: true]},
          %{name: "paragraph", type: "string", opts: [default: nil]}
        ],
        slots: [
          %{name: "announcement_badge"},
          %{name: "actions"},
          %{name: "customer_logos"}
        ],
        template: """
        <section class="bg-white dark:bg-gray-900">
          <div class="py-8 px-4 mx-auto max-w-screen-xl text-center lg:py-16 lg:px-12">
            <%= render_slot(@announcement_badge) %>
            <h1 class="mb-4 text-4xl font-extrabold tracking-tight leading-none text-gray-900 md:text-5xl lg:text-6xl dark:text-white"><%= @heading %></h1>
            <p class="mb-8 text-lg font-normal text-gray-500 lg:text-xl sm:px-16 xl:px-48 dark:text-gray-400"><%= @paragraph %></p>
            <div :for={action <- @actions} class="flex flex-col mb-8 lg:mb-16 space-y-4 sm:flex-row sm:justify-center sm:space-y-0 sm:space-x-4">
              <%= render_slot(action) %>
            </div>
            <div :for={customer_logo <- @customer_logos} class="px-4 mx-auto text-center md:max-w-screen-md lg:max-w-screen-lg lg:px-36">
              <span class="font-semibold text-gray-400 uppercase">FEATURED IN</span>
              <div class="flex flex-wrap justify-center items-center mt-8 text-gray-500 sm:justify-between">
                <%= render_slot(customer_logo) %>
              </div>
            </div>
          </div>
        </section>
        """,
        example: """
        <.flowbite_hero
          heading="We invest in the world’s potential"
          paragraph="Here at Flowbite we focus on markets where technology, innovation, and capital can unlock long-term value and drive economic growth."
        >
          <:announcement_badge>
            <.link href="#" class="inline-flex justify-between items-center py-1 px-1 pr-4 mb-7 text-sm text-gray-700 bg-gray-100 rounded-full dark:bg-gray-800 dark:text-white hover:bg-gray-200 dark:hover:bg-gray-700" role="alert">
              <span class="text-xs bg-neutral-600 rounded-full text-white px-4 py-1.5 mr-3">New</span> <span class="text-sm font-medium">Flowbite is out! See what's new</span>
              <svg class="ml-2 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path></svg>
            </.link>
          </:announcement_badge>

          <:actions>
            <.link href="#" class="inline-flex justify-center items-center py-3 px-5 text-base font-medium text-center text-white rounded-lg bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
              Learn more
              <svg class="ml-2 -mr-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path></svg>
            </.link>
            <.link href="#" class="inline-flex justify-center items-center py-3 px-5 text-base font-medium text-center text-gray-900 rounded-lg border border-gray-300 hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-700 dark:hover:bg-gray-700 dark:focus:ring-gray-800">
              <svg class="mr-2 -ml-1 w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"></path></svg>
              Watch video
            </.link>
          </:actions>

          <:customer_logos>
            <.link href="#" class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
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
            </.link>
            <.link href="#" class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
              <svg class="h-11" viewBox="0 0 208 42" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M42.7714 20.729C42.7714 31.9343 33.6867 41.019 22.4814 41.019C11.2747 41.019 2.19141 31.9343 2.19141 20.729C2.19141 9.52228 11.2754 0.438965 22.4814 0.438965C33.6867 0.438965 42.7714 9.52297 42.7714 20.729Z" fill="currentColor"/>
                <path d="M25.1775 21.3312H20.1389V15.9959H25.1775C25.5278 15.9959 25.8747 16.0649 26.1983 16.1989C26.522 16.333 26.8161 16.5295 27.0638 16.7772C27.3115 17.0249 27.508 17.319 27.6421 17.6427C27.7761 17.9663 27.8451 18.3132 27.8451 18.6635C27.8451 19.0139 27.7761 19.3608 27.6421 19.6844C27.508 20.0081 27.3115 20.3021 27.0638 20.5499C26.8161 20.7976 26.522 20.9941 26.1983 21.1281C25.8747 21.2622 25.5278 21.3312 25.1775 21.3312ZM25.1775 12.439H16.582V30.2234H20.1389V24.8881H25.1775C28.6151 24.8881 31.402 22.1012 31.402 18.6635C31.402 15.2258 28.6151 12.439 25.1775 12.439Z" fill="white"/>
                <path d="M74.9361 17.4611C74.9361 16.1521 73.9305 15.3588 72.6239 15.3588H69.1216V19.5389H72.6248C73.9313 19.5389 74.9369 18.7457 74.9369 17.4611H74.9361ZM65.8047 28.2977V12.439H73.0901C76.4778 12.439 78.3213 14.7283 78.3213 17.4611C78.3213 20.1702 76.4542 22.4588 73.0901 22.4588H69.1216V28.2977H65.8055H65.8047ZM80.3406 28.2977V16.7362H83.3044V18.2543C84.122 17.2731 85.501 16.4563 86.9027 16.4563V19.3518C86.6912 19.3054 86.4349 19.2826 86.0851 19.2826C85.1039 19.2826 83.7949 19.8424 83.3044 20.5681V28.2977H80.3397H80.3406ZM96.8802 22.3652C96.8802 20.6136 95.8503 19.0955 93.9823 19.0955C92.1364 19.0955 91.1105 20.6136 91.1105 22.366C91.1105 24.1404 92.1364 25.6585 93.9823 25.6585C95.8503 25.6585 96.8794 24.1404 96.8794 22.3652H96.8802ZM88.0263 22.3652C88.0263 19.1663 90.2684 16.4563 93.9823 16.4563C97.7198 16.4563 99.962 19.1655 99.962 22.3652C99.962 25.5649 97.7198 28.2977 93.9823 28.2977C90.2684 28.2977 88.0263 25.5649 88.0263 22.3652ZM109.943 24.3739V20.3801C109.452 19.6316 108.378 19.0955 107.396 19.0955C105.693 19.0955 104.524 20.4265 104.524 22.366C104.524 24.3267 105.693 25.6585 107.396 25.6585C108.378 25.6585 109.452 25.1215 109.943 24.3731V24.3739ZM109.943 28.2977V26.5697C109.054 27.6899 107.841 28.2977 106.462 28.2977C103.637 28.2977 101.465 26.1499 101.465 22.3652C101.465 18.6993 103.59 16.4563 106.462 16.4563C107.793 16.4563 109.054 17.0177 109.943 18.1843V12.439H112.932V28.2977H109.943ZM123.497 28.2977V26.5925C122.727 27.4337 121.372 28.2977 119.526 28.2977C117.052 28.2977 115.884 26.9431 115.884 24.7473V16.7362H118.849V23.5798C118.849 25.1451 119.666 25.6585 120.927 25.6585C122.071 25.6585 122.983 25.028 123.497 24.3731V16.7362H126.463V28.2977H123.497ZM128.69 22.3652C128.69 18.9092 131.212 16.4563 134.67 16.4563C136.982 16.4563 138.383 17.4611 139.131 18.4886L137.191 20.3093C136.655 19.5153 135.838 19.0955 134.81 19.0955C133.011 19.0955 131.751 20.4037 131.751 22.366C131.751 24.3267 133.011 25.6585 134.81 25.6585C135.838 25.6585 136.655 25.1915 137.191 24.4203L139.131 26.2426C138.383 27.2702 136.982 28.2977 134.67 28.2977C131.212 28.2977 128.69 25.8456 128.69 22.3652ZM141.681 25.1915V19.329H139.813V16.7362H141.681V13.6528H144.648V16.7362H146.935V19.329H144.648V24.3975C144.648 25.1215 145.02 25.6585 145.675 25.6585C146.118 25.6585 146.541 25.495 146.702 25.3087L147.334 27.5728C146.891 27.9714 146.096 28.2977 144.857 28.2977C142.779 28.2977 141.681 27.2238 141.681 25.1915ZM165.935 28.2977V21.454H158.577V28.2977H155.263V12.439H158.577V18.5577H165.935V12.4398H169.275V28.2977H165.935ZM179.889 28.2977V26.5925C179.119 27.4337 177.764 28.2977 175.919 28.2977C173.443 28.2977 172.276 26.9431 172.276 24.7473V16.7362H175.241V23.5798C175.241 25.1451 176.058 25.6585 177.32 25.6585C178.464 25.6585 179.376 25.028 179.889 24.3731V16.7362H182.856V28.2977H179.889ZM193.417 28.2977V21.1986C193.417 19.6333 192.602 19.0963 191.339 19.0963C190.172 19.0963 189.285 19.7504 188.77 20.4045V28.2985H185.806V16.7362H188.77V18.1843C189.495 17.3439 190.896 16.4563 192.718 16.4563C195.217 16.4563 196.408 17.8573 196.408 20.0523V28.2977H193.418H193.417ZM199.942 25.1915V19.329H198.076V16.7362H199.943V13.6528H202.91V16.7362H205.198V19.329H202.91V24.3975C202.91 25.1215 203.282 25.6585 203.936 25.6585C204.38 25.6585 204.802 25.495 204.965 25.3087L205.595 27.5728C205.152 27.9714 204.356 28.2977 203.119 28.2977C201.04 28.2977 199.943 27.2238 199.943 25.1915" fill="currentColor"/>
              </svg>
            </.link>
            <.link href="#" class="mr-5 mb-5 lg:mb-0 hover:text-gray-800 dark:hover:text-gray-400">
              <svg class="h-11" viewBox="0 0 120 41" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M20.058 40.5994C31.0322 40.5994 39.9286 31.7031 39.9286 20.7289C39.9286 9.75473 31.0322 0.858398 20.058 0.858398C9.08385 0.858398 0.1875 9.75473 0.1875 20.7289C0.1875 31.7031 9.08385 40.5994 20.058 40.5994Z" fill="currentColor"/>
                <path d="M33.3139 20.729C33.3139 19.1166 32.0101 17.8362 30.4211 17.8362C29.6388 17.8362 28.9272 18.1442 28.4056 18.6424C26.414 17.2196 23.687 16.2949 20.6518 16.1765L21.9796 9.96387L26.2951 10.8885C26.3429 11.9793 27.2437 12.8567 28.3584 12.8567C29.4965 12.8567 30.4211 11.9321 30.4211 10.7935C30.4211 9.65536 29.4965 8.73071 28.3584 8.73071C27.5522 8.73071 26.8406 9.20497 26.5086 9.89271L21.6954 8.87303C21.553 8.84917 21.4107 8.87303 21.3157 8.94419C21.1972 9.01535 21.1261 9.13381 21.1026 9.27613L19.6321 16.1999C16.5497 16.2949 13.7753 17.2196 11.7599 18.6662C11.2171 18.1478 10.495 17.8589 9.74439 17.86C8.13201 17.86 6.85156 19.1639 6.85156 20.7529C6.85156 21.9383 7.56272 22.9341 8.55897 23.3849C8.51123 23.6691 8.48781 23.9538 8.48781 24.2623C8.48781 28.7197 13.6807 32.348 20.083 32.348C26.4852 32.348 31.6781 28.7436 31.6781 24.2623C31.6781 23.9776 31.6543 23.6691 31.607 23.3849C32.6028 22.9341 33.3139 21.9144 33.3139 20.729ZM13.4434 22.7918C13.4434 21.6536 14.368 20.729 15.5066 20.729C16.6447 20.729 17.5694 21.6536 17.5694 22.7918C17.5694 23.9299 16.6447 24.855 15.5066 24.855C14.368 24.8784 13.4434 23.9299 13.4434 22.7918ZM24.9913 28.2694C23.5685 29.6921 20.8653 29.7872 20.083 29.7872C19.2768 29.7872 16.5736 29.6683 15.1742 28.2694C14.9612 28.0559 14.9612 27.7239 15.1742 27.5105C15.3877 27.2974 15.7196 27.2974 15.9331 27.5105C16.8343 28.4117 18.7314 28.7197 20.083 28.7197C21.4346 28.7197 23.355 28.4117 24.2324 27.5105C24.4459 27.2974 24.7778 27.2974 24.9913 27.5105C25.1809 27.7239 25.1809 28.0559 24.9913 28.2694ZM24.6116 24.8784C23.4735 24.8784 22.5488 23.9538 22.5488 22.8156C22.5488 21.6775 23.4735 20.7529 24.6116 20.7529C25.7502 20.7529 26.6748 21.6775 26.6748 22.8156C26.6748 23.9299 25.7502 24.8784 24.6116 24.8784Z" fill="white"/>
                <path d="M108.412 16.6268C109.8 16.6268 110.926 15.5014 110.926 14.1132C110.926 12.725 109.8 11.5996 108.412 11.5996C107.024 11.5996 105.898 12.725 105.898 14.1132C105.898 15.5014 107.024 16.6268 108.412 16.6268Z" fill="currentColor"/>
                <path d="M72.5114 24.8309C73.7446 24.8309 74.4557 23.9063 74.4084 23.0051C74.385 22.5308 74.3373 22.2223 74.29 21.9854C73.5311 18.7133 70.8756 16.2943 67.7216 16.2943C63.9753 16.2943 60.9401 19.6853 60.9401 23.8586C60.9401 28.0318 63.9753 31.4228 67.7216 31.4228C70.0694 31.4228 71.753 30.5693 72.9622 29.2177C73.5549 28.5538 73.4365 27.5341 72.7249 27.036C72.1322 26.6329 71.3972 26.7752 70.8517 27.2256C70.3302 27.6765 69.3344 28.5772 67.7216 28.5772C65.825 28.5772 64.2126 26.941 63.8568 24.7832H72.5114V24.8309ZM67.6981 19.1637C69.4051 19.1637 70.8756 20.4915 71.421 22.3173H63.9752C64.5207 20.468 65.9907 19.1637 67.6981 19.1637ZM61.0824 17.7883C61.0824 17.0771 60.5609 16.5078 59.897 16.3894C57.8338 16.0813 55.8895 16.8397 54.7752 18.2391V18.049C54.7752 17.1717 54.0636 16.6267 53.3525 16.6267C52.5697 16.6267 51.9297 17.2667 51.9297 18.049V29.6681C51.9297 30.427 52.4985 31.0908 53.2574 31.1381C54.0875 31.1854 54.7752 30.5454 54.7752 29.7154V23.7162C54.7752 21.0608 56.7668 18.8791 59.5173 19.1876H59.802C60.5131 19.1399 61.0824 18.5233 61.0824 17.7883ZM109.834 19.306C109.834 18.5233 109.194 17.8833 108.412 17.8833C107.629 17.8833 106.989 18.5233 106.989 19.306V29.7154C106.989 30.4981 107.629 31.1381 108.412 31.1381C109.194 31.1381 109.834 30.4981 109.834 29.7154V19.306ZM88.6829 11.4338C88.6829 10.651 88.0429 10.011 87.2602 10.011C86.4779 10.011 85.8379 10.651 85.8379 11.4338V17.7648C84.8655 16.7924 83.6562 16.3182 82.2096 16.3182C78.4632 16.3182 75.4281 19.7091 75.4281 23.8824C75.4281 28.0557 78.4632 31.4466 82.2096 31.4466C83.6562 31.4466 84.8893 30.9485 85.8613 29.9761C85.9797 30.6405 86.5729 31.1381 87.2602 31.1381C88.0429 31.1381 88.6829 30.4981 88.6829 29.7154V11.4338ZM82.2334 28.6245C80.0518 28.6245 78.2971 26.5145 78.2971 23.8824C78.2971 21.2742 80.0518 19.1399 82.2334 19.1399C84.4151 19.1399 86.1698 21.2504 86.1698 23.8824C86.1698 26.5145 84.3912 28.6245 82.2334 28.6245ZM103.527 11.4338C103.527 10.651 102.887 10.011 102.104 10.011C101.322 10.011 100.681 10.651 100.681 11.4338V17.7648C99.7093 16.7924 98.5 16.3182 97.0534 16.3182C93.307 16.3182 90.2719 19.7091 90.2719 23.8824C90.2719 28.0557 93.307 31.4466 97.0534 31.4466C98.5 31.4466 99.7327 30.9485 100.705 29.9761C100.824 30.6405 101.416 31.1381 102.104 31.1381C102.887 31.1381 103.527 30.4981 103.527 29.7154V11.4338ZM97.0534 28.6245C94.8717 28.6245 93.1174 26.5145 93.1174 23.8824C93.1174 21.2742 94.8717 19.1399 97.0534 19.1399C99.235 19.1399 100.99 21.2504 100.99 23.8824C100.99 26.5145 99.235 28.6245 97.0534 28.6245ZM117.042 29.7392V19.1637H118.299C118.963 19.1637 119.556 18.6656 119.603 17.9779C119.651 17.2428 119.058 16.6267 118.347 16.6267H117.042V14.6347C117.042 13.8758 116.474 13.2119 115.715 13.1646C114.885 13.1173 114.197 13.7573 114.197 14.5874V16.6501H113.011C112.348 16.6501 111.755 17.1483 111.708 17.836C111.66 18.571 112.253 19.1876 112.964 19.1876H114.173V29.7631C114.173 30.5454 114.814 31.1854 115.596 31.1854C116.426 31.1381 117.042 30.5216 117.042 29.7392Z" fill="currentColor"/>
              </svg>
            </.link>
          </:customer_logos>
        </.flowbite_hero>
        """,
        category: :section
      },
      %{
        name: "flowbite_hero_with_image",
        description: "Renders an image next to the heading and CTA buttons to improve the visual impact of the website's first visit.",
        thumbnail: "https://placehold.co/400x75?text=flowbite_hero_with_image",
        attrs: [
          %{name: "heading", type: "string", opts: [required: true]},
          %{name: "paragraph", type: "string", opts: [default: nil]},
          %{name: "image_src", type: "string", opts: [default: nil]}
        ],
        slots: [
          %{name: "actions"}
        ],
        template: """
        <section class="bg-white dark:bg-gray-900">
          <div class="grid max-w-screen-xl px-4 py-8 mx-auto lg:gap-8 xl:gap-0 lg:py-16 lg:grid-cols-12">
            <div class="mr-auto place-self-center lg:col-span-7">
              <h1 class="max-w-2xl mb-4 text-4xl font-extrabold tracking-tight leading-none md:text-5xl xl:text-6xl dark:text-white"><%= @heading %></h1>
              <p class="max-w-2xl mb-6 font-light text-gray-500 lg:mb-8 md:text-lg lg:text-xl dark:text-gray-400"><%= @paragraph %></p>
              <%= render_slot(@actions) %>
            </div>
            <div :if={@image_src} class="hidden lg:mt-0 lg:col-span-5 lg:flex">
              <img src={@image_src} alt="mockup">
            </div>
          </div>
        </section>
        """,
        example: """
        <.flowbite_hero_with_image
          heading="Payments tool for software companies"
          paragraph="From checkout to global sales tax compliance, companies around the world use Flowbite to simplify their payment stack."
          image_src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/hero/phone-mockup.png"
        >
          <:actions>
            <a href="#" class="inline-flex items-center justify-center px-5 py-3 mr-3 text-base font-medium text-center text-white rounded-lg bg-neutral-700 hover:bg-neutral-800 focus:ring-4 focus:ring-neutral-300 dark:focus:ring-neutral-900">
                Get started
                <svg class="w-5 h-5 ml-2 -mr-1" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"></path></svg>
            </a>
            <a href="#" class="inline-flex items-center justify-center px-5 py-3 text-base font-medium text-center text-gray-900 border border-gray-300 rounded-lg hover:bg-gray-100 focus:ring-4 focus:ring-gray-100 dark:text-white dark:border-gray-700 dark:hover:bg-gray-700 dark:focus:ring-gray-800">
                Speak to Sales
            </a>
          </:actions>
        </.flowbite_hero_with_image>
        """,
        category: :section
      },
      %{
        name: "flowbite_header",
        description: "Renders a heading with a paragraph and a CTA link anywhere on your page relative to other sections.",
        thumbnail: "https://placehold.co/400x75?text=flowbite_header",
        attrs: [
          %{name: "heading", type: "string", opts: [required: true]},
          %{name: "paragraph", type: "string", opts: [default: nil]},
          %{name: "paragraph_highlight", type: "string", opts: [default: nil]}
        ],
        template: """
        <section class="bg-white dark:bg-gray-900">
          <div class="py-8 px-4 mx-auto max-w-screen-xl lg:py-16 lg:px-6">
            <div class="max-w-screen-lg text-gray-500 sm:text-lg dark:text-gray-400">
              <h2 class="mb-4 text-4xl tracking-tight font-bold text-gray-900 dark:text-white"><%= @heading %></h2>
              <p class="mb-4 font-light"><%= @paragraph %></p>
              <p class="mb-4 font-medium"><%= @paragraph_highlight %></p>
              <.link href="#" class="inline-flex items-center font-medium text-neutral-600 hover:text-neutral-800 dark:text-neutral-500 dark:hover:text-neutral-700">
                  Learn more
                  <svg class="ml-1 w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
                  </svg>
              </.link>
            </div>
          </div>
        </section>
        """,
        example: """
        <.flowbite_header
          heading={{:safe, "Powering innovation at <span class='font-extrabold'>200,000+</span> companies worldwide"}}
          paragraph="Track work across the enterprise through an open, collaborative platform. Link issues across Jira and ingest data from other software development tools, so your IT support and operations teams have richer contextual information to rapidly respond to requests, incidents, and changes."
          paragraph_highlight="Deliver great service experiences fast - without the complexity of traditional ITSM solutions.Accelerate critical development work, eliminate toil, and deploy changes with ease."
        />
        """,
        category: :section
      },
      %{
        name: "flowbite_header_with_image",
        description: "Renders a couple of images next to a heading and paragraph to provide visual impact to your users..",
        thumbnail: "https://placehold.co/400x75?text=flowbite_header_with_image",
        attrs: [
          %{name: "heading", type: "string", opts: [required: true]},
          %{name: "paragraph", type: "string", opts: [default: nil]},
          %{name: "paragraph_second", type: "string", opts: [default: nil]}
        ],
        slots: [
          %{name: "inner_block", opts: [required: true]}
        ],
        template: """
        <section class="bg-white dark:bg-gray-900">
          <div class="gap-16 items-center py-8 px-4 mx-auto max-w-screen-xl lg:grid lg:grid-cols-2 lg:py-16 lg:px-6">
            <div class="font-light text-gray-500 sm:text-lg dark:text-gray-400">
                <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-gray-900 dark:text-white"><%= @heading %></h2>
                <p class="mb-4"><%= @paragraph %></p>
                <p><%= @paragraph_second %></p>
            </div>
            <%= render_slot(@inner_block) %>
          </div>
        </section>
        """,
        example: """
        <.flowbite_header_with_image
          heading="We didn't reinvent the wheel"
          paragraph="We are strategists, designers and developers. Innovators and problem solvers. Small enough to be simple and quick, but big enough to deliver the scope you want at the pace you need. Small enough to be simple and quick, but big enough to deliver the scope you want at the pace you need."
          paragraph_second="We are strategists, designers and developers. Innovators and problem solvers. Small enough to be simple and quick."
        >
          <div class="grid grid-cols-2 gap-4 mt-8">
            <img class="w-full rounded-lg" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/content/office-long-2.png" alt="office content 1">
            <img class="mt-4 w-full lg:mt-10 rounded-lg" src="https://flowbite.s3.amazonaws.com/blocks/marketing-ui/content/office-long-1.png" alt="office content 2">
          </div>
        </.flowbite_header_with_image>
        """,
        category: :section
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
  Creates a component.

  Returns the new component if successful, otherwise raises an error.
  """
  @doc type: :components
  @spec create_component!(map()) :: Component.t()
  def create_component!(attrs \\ %{}) do
    case create_component(attrs) do
      {:ok, component} ->
        component

      {:error, changeset} ->
        raise "failed to create component: #{inspect(changeset.errors)}"
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
  Creates a snippet helper.

  Returns the new helper if successful, otherwise raises an error.
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

    transact(repo(page), fn ->
      with {:ok, %PageEventHandler{}} <- repo(page).insert(changeset),
           %Page{} = page <- repo(page).preload(page, :event_handlers, force: true),
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

    transact(repo(page), fn ->
      with {:ok, %PageEventHandler{}} <- repo(page).update(changeset),
           %Page{} = page <- repo(page).preload(page, :event_handlers, force: true),
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
    with {:ok, %PageEventHandler{}} <- repo(page).delete(event_handler),
         %Page{} = page <- repo(page).preload(page, :event_handlers, force: true),
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
  Deletes a page variant and returns the page with updated variants association.
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
  Creates a new LiveData for scoping live data to pages.

  Returns the new LiveData if successful, otherwise raises an error.
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

      transact(repo(site), fn ->
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

      transact(repo(site), fn ->
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
