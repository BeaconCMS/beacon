defmodule BeaconWeb.Components do
  @moduledoc """
  """

  use Phoenix.Component

  @doc """
  Image
  """
  attr :site, :string, required: true # TODO inject or resolve :site at runtime if possible
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def image(assigns) do
    ~H"""
    <img src={"/beacon/media_library/serve?site=#{@site}&name=#{@name}"} class={@class} {@rest} />
    """
  end
end
