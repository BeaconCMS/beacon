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
  Renders the default item for featured_pages.

  ## Examples

      <BeaconWeb.Components.feature_page_item />
  """

  attr :title, :string, required: true
  attr :updated_at, :any, required: true
  attr :page_path, :string, required: true

  def feature_page_item(assigns) do
    ~H"""
    <article class="hover:ring-2 hover:ring-gray-200 hover:ring-offset-8 flex relative flex-col rounded-lg xl:hover:ring-offset-[12px] 2xl:hover:ring-offset-[16px] active:ring-gray-200 active:ring-offset-8 xl:active:ring-offset-[12px] 2xl:active:ring-offset-[16px] focus-within:ring-2 focus-within:ring-blue-200 focus-within:ring-offset-8 xl:focus-within:ring-offset-[12px] hover:bg-white active:bg-white trasition-all duration-300">
      <div class="flex flex-col">
        <div>
          <p class="font-bold text-gray-700"></p>
          <p class="text-eyebrow font-medium text-gray-500 text-sm text-left">
            <%= Calendar.strftime(@updated_at, "%d %B %Y") %>
          </p>
        </div>

        <div class="-order-1 flex gap-x-2 items-center mb-3">
          <h3 class="font-heading lg:text-xl lg:leading-8 text-lg font-bold leading-7">
            <a
              href={@page_path}
              data-phx-link="redirect"
              data-phx-link-state="push"
              class="after:absolute after:inset-0 after:cursor-pointer focus:outline-none"
            >
              <%= @title %>
            </a>
          </h3>
        </div>
      </div>
    </article>
    """
  end

  @doc """

  Renders a feature pages component.

  ## Examples

    Without pages, A.K.A, default behavior:
      <BeaconWeb.Components.featured_pages />

    With pages:
      <BeaconWeb.Components.featured_pages :let={page} pages={Beacon.Content.list_pages(...)}>
        <article >
          <%= page.title %>
        </article>
      </BeaconWeb.Components.featured_pages>
  """

  attr :pages, :list, default: []
  slot :inner_block

  def featured_pages(assigns) do
    assigns =
      if Enum.empty?(assigns.pages),
        do: Map.put(assigns, :pages, Beacon.Content.list_pages(Process.get(:__beacon_site__), per_page: 3)),
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
        <%= if Enum.empty?(@inner_block) do %>
          <div :for={page <- @pages}>
            <BeaconWeb.Components.feature_page_item title={page.title} updated_at={page.updated_at} page_path={page.path} />
          </div>
        <% else %>
          <%= for page <- @pages do %>
            <%= render_slot(@inner_block, page) %>
          <% end %>
        <% end %>
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

  attr :source, :string, default: nil

  def thumbnail(assigns) do
    ~H"""
    <image src={@source} width="50" height="50" />
    """
  end
end
