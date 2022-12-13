defmodule DummyApp.BeaconDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data("my_site", ["home"], _params), do: %{vals: ["first", "second", "third"]}

  def live_data("my_site", ["blog", blog_slug], _params),
    do: %{blog_slug_uppercase: String.upcase(blog_slug)}

  def live_data(_, _, _), do: %{}
end
