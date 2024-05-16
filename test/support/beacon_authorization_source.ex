defmodule Beacon.BeaconTest.BeaconAuthorizationSource do
  @behaviour Beacon.Authorization.Policy

  alias Beacon.Content.Page

  def get_agent(%{"session_id" => "admin_session_123"}) do
    %{role: :admin, session_id: "admin_session_123"}
  end

  def get_agent(%{"session_id" => "editor_session_123"}) do
    %{role: :editor, session_id: "editor_session_123"}
  end

  def get_agent(%{"session_id" => "other_session_123"}) do
    %{role: :other, session_id: "other_session_123"}
  end

  def get_agent(_), do: %{}

  def authorized?(%{role: :admin}, _operation, _context), do: true

  def authorized?(%{role: :editor}, :index, %{mod: :page_editor}), do: true
  def authorized?(%{role: :editor}, :edit, %{mod: :page_editor, resource: %Page{}}), do: true

  def authorized?(_, _, %{mod: :media_library}), do: true

  def authorized?(_agent, _operation, _context) do
    false
  end
end
