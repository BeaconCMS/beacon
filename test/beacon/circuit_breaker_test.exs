defmodule Beacon.CircuitBreakerTest do
  use ExUnit.Case, async: true

  alias Beacon.CircuitBreaker

  setup do
    CircuitBreaker.init()
    site = :"test_site_#{System.unique_integer([:positive])}"
    path = "/test/#{System.unique_integer([:positive])}"
    {:ok, site: site, path: path}
  end

  test "check returns :ok when circuit is not tripped", %{site: site, path: path} do
    assert CircuitBreaker.check(site, path) == :ok
  end

  test "check returns :tripped after trip", %{site: site, path: path} do
    CircuitBreaker.trip(site, path, 60)
    assert {:tripped, remaining} = CircuitBreaker.check(site, path)
    assert remaining > 0 and remaining <= 60
  end

  test "circuit auto-resets after TTL expires", %{site: site, path: path} do
    CircuitBreaker.trip(site, path, 0)
    # TTL of 0 means already expired
    assert CircuitBreaker.check(site, path) == :ok
  end

  test "reset clears a tripped circuit", %{site: site, path: path} do
    CircuitBreaker.trip(site, path, 60)
    assert {:tripped, _} = CircuitBreaker.check(site, path)

    CircuitBreaker.reset(site, path)
    assert CircuitBreaker.check(site, path) == :ok
  end

  test "different paths are independent", %{site: site} do
    CircuitBreaker.trip(site, "/path-a", 60)
    assert {:tripped, _} = CircuitBreaker.check(site, "/path-a")
    assert CircuitBreaker.check(site, "/path-b") == :ok
  end

  test "different sites are independent", %{path: path} do
    CircuitBreaker.trip(:site_a, path, 60)
    assert {:tripped, _} = CircuitBreaker.check(:site_a, path)
    assert CircuitBreaker.check(:site_b, path) == :ok
  end
end
