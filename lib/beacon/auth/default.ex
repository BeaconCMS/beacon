defmodule Beacon.Auth.Default do
  @moduledoc """
  Default Auth logic when none is provided.

  All users will be considered as `:admin`.
  """
  @behaviour Beacon.Auth

  def actor_from_session(_session), do: nil

  def check_role(_actor), do: :admin
end
