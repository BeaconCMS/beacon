defmodule Beacon.DataSource.Behaviour do
  @moduledoc """
  Provides data to your pages programmatically.

  ## Examples

  Given a module implementing data sources in your app:

      defmodule MyApp.BeaconDataSource do
        @behaviour Beacon.DataSource.Behaviour

        def live_data(:my_site, ["home"], _params), do: %{year: Date.utc_today().year}
      end

  Then an assign becomes available at your home page:

      <%= @beacon_live_data[:year] %>

  Note that module has to be linked to your site by providing
  its name to `beacon_site/2` in your app router.
  """

  @optional_callbacks page_title: 2, meta_tags: 2

  @callback live_data(Beacon.Types.Site.t(), path :: [String.t()], params :: map()) :: map()

  @type page_title_opts :: %{path: [String.t()], params: map(), beacon_live_data: map(), page_title: String.t()}
  @callback page_title(Beacon.Types.Site.t(), page_title_opts()) :: String.t()

  @type meta_tags_opts :: %{path: [String.t()], params: map(), beacon_live_data: map(), meta_tags: [map()]}
  @callback meta_tags(Beacon.Types.Site.t(), meta_tags_opts()) :: [map()]
end
