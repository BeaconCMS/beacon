defmodule Beacon.Auth.Default do
  @moduledoc """
  Default Auth logic when none is provided.
  """
  @behaviour Beacon.Auth

  def actor_from_session(_session), do: {:__beacon_default_owner__, "Default Owner"}

  def list_actors, do: []

  def owner, do: {:__beacon_default_owner__, "Default Owner"}
end
