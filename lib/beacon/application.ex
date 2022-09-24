defmodule Beacon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Beacon.Repo,
      {Phoenix.PubSub, name: Beacon.PubSub},
      # Start a worker by calling: Beacon.Worker.start_link(arg)
      # {Beacon.Worker, arg}
      Beacon.Loader.Server,
      {BeaconWeb.RuntimeCSS, Application.get_env(:beacon, BeaconWeb.RuntimeCSS)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Beacon.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
