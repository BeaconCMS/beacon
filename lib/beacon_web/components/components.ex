defmodule BeaconWeb.Components do
  @moduledoc """
  Beacon built-in Page UI components.
  """

  use Phoenix.Component
  import Beacon.Router, only: [beacon_asset_path: 2]

  @doc """
  Renders a image previously uploaded in Admin Media Library.

  ## Examples

      <BeaconWeb.Components.image name="logo.jpg" width="200px" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def image(assigns) do
    assigns = Map.put(assigns, :beacon_site, Process.get(:__beacon_site__))

    ~H"""
    <img src={beacon_asset_path(@beacon_site, @name)} class={@class} {@rest} />
    """
  end
end
