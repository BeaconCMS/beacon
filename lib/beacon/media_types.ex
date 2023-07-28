defmodule Beacon.MediaTypes do
  # Browsers' media types are often out of date,
  # returning and empty string or a deprecated assignation
  # which the elixir MIME library no longer supports.
  def normalize(""), do: nil

  def normalize("application/font-woff"), do: "font/woff"

  def normalize(media_type), do: media_type
end
