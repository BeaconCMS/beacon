defmodule Beacon.SiteSupervisor do
  @moduledoc false

  use Supervisor
  alias Beacon.Registry

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: Registry.via({:site, config.site}, config))
  end

  @impl true
  def init(config) do
    children = [
      {Beacon.Loader.Server, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
