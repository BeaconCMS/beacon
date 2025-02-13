defmodule Beacon.Auth.Default do
  @moduledoc """
  Default Auth logic when none is provided.
  """
  @behaviour Beacon.Auth

  # TODO: setup default auth for site owner

  def actor_from_session(_session), do: nil

  def list_actors, do: []
end
