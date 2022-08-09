defmodule Beacon.DataSource.Behaviour do
  @callback live_data(site :: String.t(), path :: [String.t()], params :: map()) :: map()
end
