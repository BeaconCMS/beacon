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

  defp internal_link?(%{target_path: href}) do
    cond do
      href == "" -> false
      String.starts_with?(href, "#") -> false
      String.starts_with?(href, "javascript:") -> false
      String.starts_with?(href, "mailto:") -> false
      String.starts_with?(href, "tel:") -> false
      String.starts_with?(href, "http://") -> false
      String.starts_with?(href, "https://") -> false
      String.starts_with?(href, "//") -> false
      String.starts_with?(href, "/") -> true
      true -> false
    end
  end

  defp normalize_path(path) do
    path
    |> String.split("?") |> List.first()
    |> String.split("#") |> List.first()
    |> String.trim_trailing("/")
    |> case do
      "" -> "/"
      normalized -> normalized
    end
  end
end
