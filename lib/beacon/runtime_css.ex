defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime compilation/minification of CSS files.
  """

  alias Beacon.Layouts.Layout

  require Logger

  @callback compile!(Layout.t(), keyword()) :: String.t()

  @default_compiler Beacon.CSSCompiler

  @doc """
  Compiles CSS and outputs it as a string.
  There are intermediate `tmp` files for now, due to how Tailwind CSS works.

  ### Options

   * `:config_template` - The string EEx template used as tailwind config.
     Defaults to the one in `priv/assets/tailwind.config.js.eex`.

  """
  @spec compile!(Layout.t(), keyword()) :: String.t()
  def compile!(%Layout{} = layout, opts \\ []) do
    get_compiler().compile!(layout, opts)
  end

  defp get_compiler do
    Application.get_env(:beacon, :css_compiler, @default_compiler)
  end
end
