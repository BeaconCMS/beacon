defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime compilation/minification of CSS files.
  """

  alias Beacon.Components
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  @doc """
  Compiles CSS and outputs it as a string.
  There are intermediate `tmp` files for now, due to how Tailwind CSS works.

  ### Options

   * `:config_template` - The string EEx template used as tailwind config.
     Defaults to the one in `priv/assets/tailwind.config.js.eex`.

  """
  @spec compile!(Layout.t(), keyword()) :: String.t() | no_return()
  def compile!(%Layout{} = layout, opts \\ []) do
    tmp_dir = System.tmp_dir!()
    config_file = Path.join(tmp_dir, "tailwind.config.js")
    output_file = Path.join(tmp_dir, "runtime.css")
    input_file = Path.join([:code.priv_dir(:beacon), "assets/beacon.css"])

    raw_content = [layout.body, page_templates(layout.id), component_bodies()]

    config = build_config(opts[:config_template], raw_content)

    File.write!(config_file, config)

    0 = Tailwind.run(:runtime, ~w(
      --config=#{config_file}
      --input=#{input_file}
      --output=#{output_file}
      --minify
    ))

    output = File.read!(output_file)

    cleanup!(config_file, output_file)

    output
  end

  @doc """
  Build CSS runtime config from an EEx template string.
  """
  @spec build_config(String.t() | nil, iodata()) :: String.t()
  def build_config(nil, raw_content) do
    :code.priv_dir(:beacon)
    |> Path.join("assets/tailwind.config.js.eex")
    |> EEx.eval_file(assigns: %{raw: IO.iodata_to_binary(raw_content)})
  end

  def build_config(config_template, raw_content) do
    EEx.eval_string(config_template, assigns: %{raw: IO.iodata_to_binary(raw_content)})
  end

  defp page_templates(layout_id) do
    Pages.list_page_templates_by_layout(layout_id)
  end

  defp component_bodies do
    Components.list_component_bodies()
  end

  defp cleanup!(config_file, output_file) do
    File.rm!(config_file)
    File.rm!(output_file)
  end
end
