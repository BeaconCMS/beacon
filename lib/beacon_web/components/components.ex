defmodule BeaconWeb.Components do
  @moduledoc """
  Beacon built-in Page UI components.
  """

  use Phoenix.Component
  import Beacon.Router, only: [beacon_asset_path: 2]

  @doc false
  def render(fun, assigns, env) do
    fun
    |> Phoenix.LiveView.TagEngine.component(assigns, env)
    |> Phoenix.HTML.Safe.to_iodata()
  end

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
  Renders a the amount in minutes for a page to be read.

  ## Examples

      <BeaconWeb.Components.reading_time />
  """

  def reading_time(assigns) do
    %{template: content} = Beacon.Content.get_page_by(Process.get(:__beacon_site__), path: Process.get(:__beacon_page_path__))
    content_without_html_tags = String.replace(content, ~r/(<[^>]*>|\n|\s{2,})/, "", global: true)
    words_per_minute = 270
    estimated_time_in_minutes = Kernel.trunc((String.split(content_without_html_tags, " ") |> length()) / words_per_minute)
    assigns = Map.put(assigns, :estimated_time_in_minutes, estimated_time_in_minutes)

    ~H"""
    <%= @estimated_time_in_minutes %> min read
    """
  end

  @doc """
  Renders a image previously uploaded in Admin Media Library with srcset.

  ## Examples

      <BeaconWeb.Components.image_set name="logo.jpg" width="200px" sources={["480w", "800w"]} sizes="(max-width: 600px) 480px, 800px" />
  """

  attr :class, :string, default: nil
  attr :sizes, :string, default: nil
  attr :sources, :list, default: [], doc: "a list of usage_tags"
  attr :asset, :map, required: true, doc: "a MediaLibrary.Asset struct"
  attr :rest, :global

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
