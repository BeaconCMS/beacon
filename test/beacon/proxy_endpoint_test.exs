defmodule Beacon.ProxyEndpointTest do
  use ExUnit.Case, async: true
  use Beacon.Test

  alias Beacon.ProxyEndpoint

  describe "url_host" do
    test "defaults to localhost when no host is found" do
      assert ProxyEndpoint.url_host(:my_site, nil) == "localhost"
    end

    test "resolves to existing host when defined" do
      assert ProxyEndpoint.url_host(:host_test, :local) == "local.mysite.com"
    end
  end
end
