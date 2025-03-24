defmodule Beacon.BeaconTest.AuthModule do
  @behaviour Beacon.Auth

  def actor_from_session(_session) do
    {"1-1-1", "Test User"}
  end

  def list_actors do
    [
      {"1-2-3", "Owner 1"},
      {"4-5-6", "Owner 2"},
      {"3-3-3", "User 1"},
      {"4-4-4", "User 2"}
    ]
  end

  def owners do
    [{"1-2-3", "Owner 1"}, {"4-5-6", "Owner 2"}]
  end
end
