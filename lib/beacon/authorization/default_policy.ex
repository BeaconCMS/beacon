defmodule Beacon.Authorization.DefaultPolicy do
  @behaviour Beacon.Authorization.Behaviour

  @impl true
  def get_agent(data), do: data

  @impl true
  def authorized?(_agent, _operation, _context), do: true
end
