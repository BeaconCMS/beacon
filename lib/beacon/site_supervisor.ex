defmodule Beacon.SiteSupervisor do
  @moduledoc false

  use Supervisor
  alias Beacon.Registry

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: Registry.via({:site, config.site}, config))
  end

  @impl true
  def init(config) do
    children =
      # start Loader process by demand under the test process
      if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
        []
      else
        [{Beacon.Loader, config}]
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
