defmodule Beacon.CSSCompiler do
  @moduledoc """
  Default CSS compiler for the runtime CSS compilation.
  """

  alias Beacon.Components
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  @behaviour Beacon.RuntimeCSS

  @impl Beacon.RuntimeCSS
  def compile!(%Layout{} = layout, opts \\ []) do
    input_file = Path.join(:code.priv_dir(:beacon), "assets/beacon.css")
    raw_content = [layout.body, page_templates(layout.id), component_bodies()]
    config = build_config(opts[:config_template], raw_content)
    {tmp_dir, config_file} = write_file("tailwind.config.js", config)
    output_file = Path.join(tmp_dir, "runtime.css")

    exit_code = Tailwind.run(:runtime, ~w(
      --config=#{config_file}
      --input=#{input_file}
      --output=#{output_file}
      --minify
      ))

    case exit_code do
      0 ->
        compiled_css = File.read!(output_file)
        cleanup(tmp_dir, config_file, output_file)
        compiled_css

      exit_code ->
        cleanup(tmp_dir, config_file, output_file)
        raise "Error running tailwind with exit code #{exit_code}"
    end
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

  defp component_bodies do
    Components.list_component_bodies()
  end

  defp page_templates(layout_id) do
    Pages.list_page_templates_by_layout(layout_id)
  end

  defp write_file(filename, content) do
    tmp_dir = Path.join(System.tmp_dir!(), random_dir())

    if File.exists?(tmp_dir) do
      write_file(filename, content)
    else
      filepath = Path.join(tmp_dir, filename)
      File.mkdir_p!(tmp_dir)
      File.write!(filepath, content)
      {tmp_dir, filepath}
    end
  end

  defp random_dir, do: :crypto.strong_rand_bytes(12) |> Base.encode16()

  defp cleanup(tmp_dir, config_file, output_file) do
    File.rm(config_file)
    File.rm(output_file)
    File.rmdir(tmp_dir)
  end
end
