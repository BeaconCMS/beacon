defmodule Beacon.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Starts just the minimum required apps for beacon to work.
    # - Keep loading sites as children of main sup to have control of where and when to trigger it.
    # - Loading repo allows to run seeds without triggering module and css recompilation.
    children = [
      Beacon.Registry,
      {Phoenix.PubSub, name: Beacon.PubSub},
      Beacon.Repo
    ]

    Beacon.Router.init()

    :ets.new(:beacon_assets, [:set, :named_table, :public, read_concurrency: true])

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
