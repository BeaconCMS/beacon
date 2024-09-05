defmodule Beacon.Web.Components do
  @moduledoc false

  use Phoenix.Component

  @doc false
  def render(fun, assigns, env) do
    fun
    |> Phoenix.LiveView.TagEngine.component(assigns, env)
    |> Phoenix.HTML.Safe.to_iodata()
  end

  @doc """
  Renders a image previously uploaded in Admin Media Library with srcset.

  ## Examples

      <Beacon.Web.Components.image_set name="logo.jpg" width="200px" sources={["480w", "800w"]} sizes="(max-width: 600px) 480px, 800px" />

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

  attr :source, :string, default: nil

  def thumbnail(assigns) do
    ~H"""
    <image src={@source} width="50" height="50" />
    """
  end
end
