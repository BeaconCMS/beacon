defmodule Beacon.SiteSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: Beacon.Registry.via({:site, config.site}))
  end

  @impl true
  def init(config) do
    children = [
      {Beacon.Config, config},
      {Task.Supervisor, name: Beacon.Registry.via({config.site, TaskSupervisor})},
      {Beacon.Content, config},
      {Beacon.RouterServer, config},
      {DynamicSupervisor,
       name: Beacon.Registry.via({config.site, Beacon.LoaderSupervisor}), strategy: :one_for_one, max_restarts: 10, max_seconds: 30},
      {Beacon.Loader, config},
      {Beacon.Boot, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
