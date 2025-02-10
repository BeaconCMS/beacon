defmodule Beacon.Web.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint Beacon.BeaconTest.ProxyEndpoint

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
