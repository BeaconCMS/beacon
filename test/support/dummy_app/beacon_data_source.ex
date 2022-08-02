defmodule DummyApp.BeaconDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data("my_site", ["home"], _params), do: %{vals: ["first", "second", "third"]}
end
