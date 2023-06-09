defmodule Beacon.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :beacon,
    adapter: Ecto.Adapters.Postgres
end
