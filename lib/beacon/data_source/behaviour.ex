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

  @callback live_data(Beacon.Type.Site.t(), path :: [String.t()], params :: map()) :: map()
end
