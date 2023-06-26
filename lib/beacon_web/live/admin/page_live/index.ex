defmodule BeaconWeb.Admin.PageLive.Index do
  use BeaconWeb, :live_view

  alias Beacon.Authorization
  alias Beacon.Content
  alias BeaconWeb.Admin.Hooks

  on_mount {Hooks.Authorized, {:page_editor, :index}}

  defmodule SearchForm do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :query, :string, default: ""
      field :site, Beacon.Types.Site
    end

    def changeset(form \\ %__MODULE__{}, params \\ %{}) do
      form
      |> cast(params, [:query, :site])
      |> validate_required([:site])
    end

    def apply_search_action(changeset) do
      apply_action(changeset, :search)
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:authn_context, %{mod: :page_editor})
      |> assign(:last_reload_time, nil)
      |> assign_site_options()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    if Authorization.authorized?(assigns.agent, assigns.live_action, assigns.authn_context) do
      {:noreply, apply_action(socket, assigns.live_action, params)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reload_pages", _, socket) do
    start = :os.system_time(:millisecond)
    Beacon.reload_all_sites()

    {:noreply, assign(socket, :last_reload_time, :os.system_time(:millisecond) - start)}
  end

  @impl true
  def handle_event("search", %{"search_form" => params}, socket) do
    query_params = URI.encode_query(params)
    {:noreply, push_patch(socket, to: beacon_admin_path(socket, "/pages?#{query_params}"), replace: true)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Page")
    |> assign(:page, Content.get_page!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Page")
    |> assign(:page, %Content.Page{})
  end

  defp apply_action(socket, :index, params) do
    socket
    |> assign(:page_title, "Listing Pages")
    |> assign(:page, nil)
    |> assign_search_changeset(params)
    |> assign_pages()
  end

  # Perform the search when the search form is valid
  defp assign_pages(socket) do
    pages =
      case SearchForm.apply_search_action(socket.assigns.search_changeset) do
        {:ok, %SearchForm{} = search_form} ->
          Content.list_pages(search_form.site, query: search_form.query)

        {:error, _changeset} ->
          []
      end

    assign(socket, :pages, pages)
  end

  # Set options for the site select input
  defp assign_site_options(socket) do
    assign(socket, :site_options, Content.list_distinct_sites_from_layouts())
  end

  # Cast search form params
  defp assign_search_changeset(socket, params) do
    default_site =
      case socket.assigns.site_options do
        [] -> nil
        [site | _] -> site
      end

    assign(socket, :search_changeset, SearchForm.changeset(%SearchForm{site: default_site}, params))
  end
end
