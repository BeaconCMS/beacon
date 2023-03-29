defmodule Beacon.BeaconTest.BeaconAuthorizationSource do
  @behaviour Beacon.Authorization.Behaviour

  alias Beacon.Admin.MediaLibrary.Asset
  alias Beacon.Pages.Page

  def get_agent(%{session_id: "admin_session_123"}) do
    %{role: :admin, session_id: "admin_session_123"}
  end

  def get_agent(%{session_id: "editor_session_123"}) do
    %{role: :editor, session_id: "editor_session_123"}
  end

  def get_agent(%{session_id: "other_session_123"}) do
    %{role: :other, session_id: "other_session_123"}
  end

  def get_agent(_), do: %{}

  def authorized?(%{role: :admin}, _operation, _context), do: true
  def authorized?(%{role: :editor}, :index, %Page{}), do: true
  def authorized?(%{role: :editor}, :edit, %Page{}), do: true
  def authorized?(%{role: :editor}, :index, %Asset{}), do: true
  def authorized?(%{role: :editor}, :search, %Asset{}), do: true
  def authorized?(%{role: :editor}, :upload, %Asset{}), do: true
  def authorized?(%{role: :editor}, _operation, _context), do: false
  def authorized?(%{role: :other}, _operation, _context), do: false
  def authorized?(_agent, _operation, _context), do: true
end
