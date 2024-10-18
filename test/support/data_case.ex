defmodule Beacon.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Beacon.BeaconTest.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      use Beacon.Test
      import Beacon.DataCase
    end
  end

  setup tags do
    Beacon.DataCase.setup_sandbox(tags)
    Process.flag(:error_handler, Beacon.ErrorHandler)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Beacon.BeaconTest.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
