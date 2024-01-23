defmodule Beacon.DataSource.Behaviour do
  @moduledoc false

  @callback live_data(
              path :: [String.t()],
              params :: map()
            ) :: map()
end
