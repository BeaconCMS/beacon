defmodule Beacon.Authorization.DefaultPolicyTest do
  use ExUnit.Case, async: true

  alias Beacon.Authorization.DefaultPolicy

  describe "get_agent/1" do
    test "passes data through" do
      assert %{session_id: "admin_session_123"} = DefaultPolicy.get_agent(%{session_id: "admin_session_123"})
    end
  end

  describe "authorized?/3" do
    test "returns true" do
      assert DefaultPolicy.authorized?(%{role: :editor}, :upload, %{})
      assert DefaultPolicy.authorized?(%{role: :admin}, :upload, %{})
    end
  end
end
