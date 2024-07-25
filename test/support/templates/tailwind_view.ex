defmodule Beacon.Web.TailwindView do
  @moduledoc false
  use Beacon.Web, :html

  def render(_, assigns) do
    ~H"""
    <div class="text-red-50"></div>
    """
  end
end
