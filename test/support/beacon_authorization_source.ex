defmodule Beacon.BeaconTest.BeaconAuthorizationSource do
  @behaviour Beacon.Authorization.Behaviour

  def get_agent(%{session_id: "admin_session_123"}) do
    %{role: :admin, session_id: "admin_session_123"}
  end

  def get_agent(%{session_id: "editor_session_123"}) do
    %{role: :editor, session_id: "editor_session_123"}
  end

  def get_agent(_), do: %{}

  def authorized?(%{role: :admin}, _operation, _context), do: true
  def authorized?(%{role: :editor}, _operation, _context), do: false
  def authorized?(_agent, _operation, _context), do: true
end
