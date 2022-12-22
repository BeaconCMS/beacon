defmodule Beacon.TestView do
  @moduledoc false
  use BeaconWeb, :html

  def render(_, assigns) do
    ~H"""
    <div class="bcms-test-text-red-800 text-red-100"></div>
    """
  end
end
