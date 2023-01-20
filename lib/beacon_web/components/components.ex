defmodule BeaconWeb.Components do
  @moduledoc """
  """

  use Phoenix.Component
  import Beacon.Router, only: [beacon_asset_path: 2]
  alias Beacon.BeaconAttrs

  @doc """
  Image
  """
  attr :beacon_attrs, BeaconAttrs, required: true
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def image(assigns) do
    ~H"""
    <img src={beacon_asset_path(@beacon_attrs, @name)} class={@class} {@rest} />
    """
  end
end
