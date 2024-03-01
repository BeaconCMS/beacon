defmodule Beacon.Authorization.DefaultPolicy do
  @moduledoc """
  Provide a simple authorization policy that allows every operation for any agent.

  That's the default policy used when no other is defined.
  """

  @behaviour Beacon.Authorization.Policy

  @impl true
  def get_agent(data), do: data

  @impl true
  def authorized?(_agent, _operation, _context), do: true
end
