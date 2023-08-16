defmodule Beacon.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Beacon.Authorization

  describe "get_agent/1" do
    test "returns agent" do
      assert %{role: :admin} = Authorization.get_agent(:my_site, %{"session_id" => "admin_session_123"})
    end
  end

  describe "authorized?/3" do
    test "returns boolean" do
      refute Authorization.authorized?(:my_site, %{role: :editor}, :upload, %{})
      assert Authorization.authorized?(:my_site, %{role: :admin}, :upload, %{})
    end
  end
end
