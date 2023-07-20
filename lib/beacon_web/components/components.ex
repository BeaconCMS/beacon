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

  @doc """
  Renders a image previously uploaded in Admin Media Library with srcset.

  ## Examples

      <BeaconWeb.Components.image name="logo.jpg" width="200px" sources={["480w", "800w"]} sizes="(max-width: 600px) 480px, 800px"/>
  """

  attr :class, :string, default: nil
  attr :sizes, :string, default: nil
  attr :rest, :global
  attr :sources, :list, default: [], doc: "a list of usage_tags"
  attr :asset, :map, required: true, doc: "a MediaLibrary.Asset struct"

  def image_set(assigns) do
    assigns =
      assigns
      |> assign(:srcset, Beacon.MediaLibrary.srcset_for_image(assigns.asset, assigns.sources))
      |> assign(:src, Beacon.MediaLibrary.url_for(assigns.asset))

    ~H"""
    <img src={@src} class={@class} {@rest} sizes={@sizes} srcset={@srcset} />
    """
  end
end
