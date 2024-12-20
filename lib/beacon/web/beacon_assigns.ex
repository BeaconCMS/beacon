defmodule Beacon.Web.BeaconAssigns do
  @moduledoc """
  Read-only container of Beacon assigns related to the current page.

  Available as `@beacon`

  This data can be accessed in page templates, event handlers, and other parts of your site
  to read information about the current page as the current site, path and query params,
  path and title.

  More fields may be added in the future.

  ## Examples

  In a template:

      <h1><%= @beacon.page.title %></h1>

  In a event handler:

      pages = Beacon.Content.list_published_pages(@beacon.site)

  """

  @derive {Inspect, only: [:site, :path_params, :query_params, :page]}

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path_params: %{String.t() => term()},
          query_params: %{String.t() => term()},
          page: %{path: String.t(), title: String.t()},
          private: map()
        }

  defstruct site: nil,
            path_params: nil,
            query_params: nil,
            page: %{path: nil, title: nil},
            private: %{
              page_module: nil,
              components_module: nil,
              info_handlers_module: nil,
              event_handlers_module: nil,
              live_data_keys: [],
              live_path: [],
              variant_roll: nil
            }

  @doc false
  def new(site) when is_atom(site) do
    components_module = Beacon.Loader.Components.module_name(site)
    %__MODULE__{site: site, private: %{components_module: components_module}}
  end

  @doc false
  def new(%Beacon.Content.Page{} = page, metadata \\ []) do
    path_info = Keyword.get(metadata, :path_info, [])
    query_params = Keyword.get(metadata, :query_params, %{})
    variant_roll = Keyword.get(metadata, :variant_roll, nil)

    page_module = Beacon.Loader.Page.module_name(page.site, page.id)
    live_data = Beacon.Web.DataSource.live_data(page.site, path_info, Map.drop(query_params, ["path"]))
    path_params = Beacon.Router.path_params(page.path, path_info)
    page_title = Beacon.Web.DataSource.page_title(page, live_data)
    components_module = Beacon.Loader.Components.module_name(page.site)
    info_handlers_module = Beacon.Loader.InfoHandlers.module_name(page.site)
    event_handlers_module = Beacon.Loader.EventHandlers.module_name(page.site)

    %__MODULE__{
      site: page.site,
      path_params: path_params,
      query_params: query_params,
      page: %{path: page.path, title: page_title},
      private: %{
        page_module: page_module,
        components_module: components_module,
        info_handlers_module: info_handlers_module,
        event_handlers_module: event_handlers_module,
        live_data_keys: Map.keys(live_data),
        live_path: path_info,
        variant_roll: variant_roll
      }
    }
  end
end
