defmodule DummyApp.Repo do
  use Ecto.Repo,
    otp_app: :dummy_app,
    adapter: Ecto.Adapters.Postgres
end
