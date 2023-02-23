defmodule BeaconWeb.TailwindView do
  @moduledoc false
  use BeaconWeb, :html

  def render(_, assigns) do
    ~H"""
    <div class="text-red-50"></div>
    """
  end
end
