defmodule Beacon.PathParser do
  @behaviour Beacon.PathParser.Behaviour

  def parse(site, path, params) do
    get_path_parser().parse(site, path, params)
  end

  def get_path_parser do
    Application.get_env(:beacon, :path_parser, Beacon.PathParser.Impl)
  end
end
