defmodule Beacon.SEO.OGImageGenerator do
  @moduledoc """
  Behaviour for dynamic OG image generation.

  Implement this behaviour to auto-generate Open Graph images from page
  metadata. The generated image is cached in the media library and served
  via `/__beacon_media__/og/`.

  ## Example

      defmodule MyApp.OGImageGenerator do
        @behaviour Beacon.SEO.OGImageGenerator

        @impl true
        def generate(manifest, config) do
          # Build an SVG or use an image library to create 1200x630 PNG
          title = manifest[:og_title] || manifest[:title] || ""
          svg = ~S(<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
            <rect width="1200" height="630" fill="#1a1a2e"/>
            <text x="100" y="315" fill="white" font-size="48" font-family="sans-serif">) <> title <> ~S(</text>
          </svg>)

          # Convert SVG to PNG (e.g. via Vix/libvips, Image, or external service)
          case convert_svg_to_png(svg) do
            {:ok, png_binary} -> {:ok, png_binary, "image/png"}
            error -> error
          end
        end

        @impl true
        def cache_key(manifest, _config) do
          :crypto.hash(:sha256, manifest[:title] || "")
          |> Base.encode16(case: :lower)
          |> binary_part(0, 16)
        end
      end

  ## Configuration

      config :beacon, :sites, [
        [
          site: :my_site,
          og_image_generator: MyApp.OGImageGenerator,
          ...
        ]
      ]

  When a page has no `og_image` set and an `og_image_generator` is configured,
  Beacon will call `generate/2` at publish time and store the result in the
  media library. The generated image URL is then used as the page's OG image.
  """

  @doc """
  Generate an OG image for the given page manifest.

  Returns `{:ok, binary_data, content_type}` on success.
  The binary_data should be a PNG or JPEG image, ideally 1200x630 pixels.
  """
  @callback generate(manifest :: map(), config :: Beacon.Config.t()) ::
              {:ok, binary(), String.t()} | {:error, term()}

  @doc """
  Generate a cache key for the OG image.

  The cache key determines when to regenerate. If the key changes between
  publishes, the image is regenerated. Return a stable string derived from
  the page content that affects the image (typically the title).
  """
  @callback cache_key(manifest :: map(), config :: Beacon.Config.t()) :: String.t()

  @optional_callbacks [cache_key: 2]
end
