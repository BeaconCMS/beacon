defmodule BeaconWeb.TailwindView do
  @moduledoc false
  use BeaconWeb, :html

  def render(_, assigns) do
    ~H"""
    <div class="bcms-test-text-red-50"></div>
    """
  end
end
