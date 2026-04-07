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
              live_data_keys: [],
              live_path: [],
              variant_roll: nil
            }

  @doc false
  def new(site) when is_atom(site) do
    %__MODULE__{site: site}
  end
end
