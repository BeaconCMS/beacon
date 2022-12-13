defmodule DummyApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      DummyAppWeb.Telemetry,
      # Start the Ecto repository
      DummyApp.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: DummyApp.PubSub},
      # Start Finch
      {Finch, name: DummyApp.Finch},
      # Start the Endpoint (http/https)
      DummyAppWeb.Endpoint
      # Start a worker by calling: DummyApp.Worker.start_link(arg)
      # {DummyApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DummyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DummyAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
