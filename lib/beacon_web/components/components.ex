defmodule BeaconWeb.Components do
  @moduledoc """
  """

  use Phoenix.Component
  import Beacon.Router, only: [beacon_media_library_asset_path: 2]

  @doc """
  Image
  """
  attr :beacon, :any, required: true # TODO: define a name and struct
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def image(assigns) do
    ~H"""
    <img src={beacon_media_library_asset_path(@beacon, @name)} class={@class} {@rest} />
    """
  end
end
