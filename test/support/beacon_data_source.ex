defmodule Beacon.BeaconTest.BeaconDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data(:my_site, ["home"], _params), do: %{vals: ["first", "second", "third"]}
  def live_data(:my_site, _path, _params), do: []
end
