defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime compilation/minification of CSS files.
  """

  alias Beacon.Layouts.Layout

  require Logger

  @callback compile!(Layout.t()) :: String.t()

  @doc """
  Compiles CSS and outputs it as a string.
  There are intermediate `tmp` files for now, due to how Tailwind CSS works.
  """
  @spec compile!(Layout.t()) :: String.t()
  def compile!(%Layout{} = layout) do
    get_compiler(layout.site).compile!(layout)
  end

  defp get_compiler(site) do
    Beacon.Config.fetch!(site).css_compiler
  end
end
