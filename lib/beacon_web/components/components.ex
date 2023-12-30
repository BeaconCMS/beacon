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
    <%= @estimated_time_in_minutes %>
    """
  end

  @doc """
  Renders a feature page item to be used in the BeaconWeb.Components.featured_pages component.

  ## Examples

      <BeaconWeb.Components.feature_page_item />
  """

  attr :title, :string, required: true
  attr :published_date, :any, required: true
  attr :image_path, :string, required: true

  def feature_page_item(assigns) do
    ~H"""
    <article class="hover:ring-2 hover:ring-gray-200 hover:ring-offset-8 flex relative flex-col rounded-lg xl:hover:ring-offset-[12px] 2xl:hover:ring-offset-[16px] active:ring-gray-200 active:ring-offset-8 xl:active:ring-offset-[12px] 2xl:active:ring-offset-[16px] focus-within:ring-2 focus-within:ring-blue-200 focus-within:ring-offset-8 xl:focus-within:ring-offset-[12px] hover:bg-white active:bg-white trasition-all duration-300">
      <div class="flex flex-col">
        <h3 class="font-heading lg:text-xl lg:leading-8 text-lg font-bold leading-7">
          <a href="#" data-phx-link="redirect" data-phx-link-state="push" class="after:absolute after:inset-0 after:cursor-pointer focus:outline-none">
            <%= @title %>
          </a>
        </h3>

        <div class="-order-1 flex gap-x-2 items-center mb-3">
          <div>
            <p class="font-bold text-gray-700"></p>
            <p class="text-eyebrow font-medium text-gray-500">
              <time datetime="2023-09-19">
                <%= DateTime.to_string(@published_date) %>
              </time>
            </p>
          </div>
        </div>
      </div>
      <div class="-order-1 mb-6 h-72">
        <img class="object-cover w-full h-full rounded-2xl" src={@image_path} alt="Narwin" loading="lazy" data-test-article-illustration="" />
      </div>
    </article>
    """
  end

  @doc """

  Renders a feature pages component.

  ## Examples

      <BeaconWeb.Components.featured_pages />
  """

  attr :site_pages, :list, default: []

  def featured_pages(assigns) do
    assigns =
      if Enum.empty?(assigns.site_pages),
        do: Map.put(assigns, :site_pages, Beacon.Content.list_pages(Process.get(:__beacon_site__), per_page: 3)),
        else: assigns

    ~H"""
    <div class="max-w-7xl mx-auto">
      <div class="lg:mb-8 xl:mb-10 flex flex-col mb-6 text-center">
        <h2 class="font-heading lg:text-3xl lg:leading-normal text-2xl font-medium" id="blogs-heading" data-test-article-shelf-heading="">
          Our Featured Blog Posts
        </h2>
        <h3 class="font-heading -order-1 lg:mb-3 lg:text-base text-eyebrow tracking-widestXl text-slate-600 mb-2 font-medium uppercase">
          Recommended Reading
        </h3>
      </div>

      <div class="md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-6 lg:gap-11 md:space-y-0 space-y-10">
        <div :for={site_page <- @site_pages}>
          <BeaconWeb.Components.feature_page_item title={site_page.title} published_date={site_page.inserted_at} image_path="#" />
        </div>
      </div>
    </div>
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
