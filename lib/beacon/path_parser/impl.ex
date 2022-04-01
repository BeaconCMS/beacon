defmodule Beacon.PathParser.Impl do
  @behaviour Beacon.PathParser.Behaviour

  def parse(_site, path, _params), do: {path, %{}}
end
