defmodule Beacon.MediaTypes do
  @moduledoc """
  #{__MODULE__} serves as a context to encapsulate business logic
  around media types that is not handled by the MIME library.

  Primary concerns:
    - Convenience functions
    - Functions to handle edge cases between the browser and Elixir
  """

  @doc """
  Browsers' media types are often out of date,
  returning an empty string or a deprecated media type
  which the Elixir MIME library no longer supports.
  """
  def normalize(""), do: nil
  def normalize("application/font-woff"), do: "font/woff"
  def normalize(media_type), do: media_type
end
