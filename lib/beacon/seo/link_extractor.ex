defmodule Beacon.SEO.LinkExtractor do
  @moduledoc """
  Extracts internal links from rendered HTML using Floki.
  """

  @doc """
  Extracts internal links from HTML string.

  Returns a list of `%{target_path: "/...", anchor_text: "..."}` maps.
  Only includes links with internal paths (relative or same-host).
  Excludes anchors (#), javascript:, mailto:, tel:, and external URLs.
  """
  @spec extract(String.t()) :: [%{target_path: String.t(), anchor_text: String.t()}]
  def extract(html) when is_binary(html) do
    case Floki.parse_fragment(html) do
      {:ok, tree} ->
        tree
        |> Floki.find("a[href]")
        |> Enum.map(fn element ->
          href = Floki.attribute(element, "href") |> List.first() || ""
          text = Floki.text(element) |> String.trim()
          %{target_path: href, anchor_text: text}
        end)
        |> Enum.filter(&internal_link?/1)
        |> Enum.map(fn link ->
          %{link | target_path: normalize_path(link.target_path)}
        end)
        |> Enum.uniq_by(& &1.target_path)

      _ ->
        []
    end
  end

  # Anything that leaves the site, opens a client, or points within the page.
  @external_prefixes ["#", "javascript:", "mailto:", "tel:", "http://", "https://", "//"]

  defp internal_link?(%{target_path: href}) do
    String.starts_with?(href, "/") and not String.starts_with?(href, @external_prefixes)
  end

  defp normalize_path(path) do
    path
    |> String.split("?")
    |> List.first()
    |> String.split("#")
    |> List.first()
    |> String.trim_trailing("/")
    |> case do
      "" -> "/"
      normalized -> normalized
    end
  end
end
