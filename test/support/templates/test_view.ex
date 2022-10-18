defmodule Beacon.TestView do
  @moduledoc false
  use BeaconWeb, :view

  def render(_, assigns) do
    ~H"""
    <div class="bcms-test-text-red-800 text-red-100"></div>
    """
  end
end
