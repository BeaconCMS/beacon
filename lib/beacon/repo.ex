defmodule Beacon.Repo do
  use Ecto.Repo,
    otp_app: :beacon,
    adapter: Ecto.Adapters.Postgres
end
