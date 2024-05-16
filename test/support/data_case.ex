defmodule Beacon.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Beacon.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Beacon.Fixtures
      import Beacon.DataCase
    end
  end

  setup tags do
    Beacon.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Beacon.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
