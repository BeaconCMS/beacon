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

    # Stub the runtime CSS compiler unless we have a tag.
    # (So we can test the compiler).
    unless tags[:runtime_css] do
      Beacon.RuntimeCSS
      |> Mimic.stub(:compile!, fn _layout, _opts -> "" end)
      |> Mimic.stub(:compile!, fn _layout -> "" end)
    end

    :ok
  end
end
