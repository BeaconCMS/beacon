defmodule Beacon.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :beacon,
    adapter: Application.compile_env(:beacon, [Beacon.Repo, :adapter], Ecto.Adapters.Postgres)

  # https://medium.com/very-big-things/towards-maintainable-elixir-the-core-and-the-interface-c267f0da43
  def transact(fun) when is_function(fun) do
    Beacon.Repo.transaction(fn ->
      case fun.() do
        {:ok, result} -> result
        {:error, reason} -> Beacon.Repo.rollback(reason)
        reason -> Beacon.Repo.rollback(reason)
      end
    end)
  end
end
