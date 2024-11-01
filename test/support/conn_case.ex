defmodule Beacon.Web.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint Beacon.BeaconTest.Endpoint

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      use Beacon.Test
      import Beacon.Web.ConnCase
    end
  end

  setup tags do
    Beacon.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
