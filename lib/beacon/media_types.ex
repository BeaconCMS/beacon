defmodule Beacon.MediaTypes do
  @moduledoc false

  @doc """
  Browsers' media types are often out of date,
  returning an empty string or a deprecated media type
  which the Elixir MIME library no longer supports.
  """
  def normalize(""), do: nil
  def normalize("application/font-woff"), do: "font/woff"
  def normalize(media_type), do: media_type
end
