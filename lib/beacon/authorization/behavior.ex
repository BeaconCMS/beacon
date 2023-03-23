defmodule Beacon.Authorization.Behaviour do
  @moduledoc """
    Provides hooks into Beacon Authorization

    ## Examples

  """

  # returns agent
  @callback get_agent(payload :: any()) :: any()

  # operation, agent, context
  @callback authorized?(agent :: any(), operation :: atom(), context :: any()) :: boolean()
end
