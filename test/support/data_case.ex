defmodule Beacon.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Beacon.Repo

      import Ecto.Changeset
      import Ecto.Query
      import Beacon.DataCase
    end
  end

  alias Ecto.Adapters.SQL.Sandbox

  setup tags do
    :ok = Sandbox.checkout(Beacon.Repo)

    unless tags[:async] do
      Sandbox.mode(Beacon.Repo, {:shared, self()})
    end

    # By default, don't run the CSS compiler.
    Mox.stub(CSSCompilerMock, :compile!, fn _layout, _opts -> "" end)

    :ok
  end
end
