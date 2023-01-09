defmodule Beacon.CSSCompiler do
  @moduledoc """
  Default CSS compiler for the runtime CSS compilation.
  """

  alias Beacon.Components
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  @behaviour Beacon.RuntimeCSS

  @template_tailwind_config_path Path.join("assets", "tailwind.config.js.eex")
  @input_css_path Path.join(["assets", "css", "app.css"])

  @external_resource @template_tailwind_config_path
  @external_resource @input_css_path

  @impl Beacon.RuntimeCSS
  def compile!(%Layout{} = layout, opts \\ []) do
    required_tailwind = Beacon.tailwind_version()
    case Application.get_env(:tailwind, :version, nil) do
      nil -> Application.put_env(:tailwind, :version, required_tailwind)
      ^required_version -> nil
      other -> raise "Beacon requires Tailwind version #{required_tailwind} but found #{other}"
    end
    Application.put_env(:tailwind, :beacon_runtime, [])

    raw_content = [layout.body, page_templates(layout.id), component_bodies()]
    config = build_config(opts[:config_template], raw_content)
    {tmp_dir, config_file} = write_file("tailwind.config.js", config)
    output_css_path = Path.join(tmp_dir, "runtime.css")

    exit_code = Tailwind.run(:beacon_runtime, ~w(
      --config=#{config_file}
      --input=#{@input_css_path}
      --output=#{output_css_path}
      --minify
      ))

    case exit_code do
      0 ->
        compiled_css = File.read!(output_css_path)
        cleanup(tmp_dir, config_file, output_css_path)
        compiled_css

      exit_code ->
        cleanup(tmp_dir, config_file, output_css_path)
        raise "Error running tailwind with exit code #{exit_code}"
    end
  end

  @doc """
  Build CSS runtime config from an EEx template string.
  """
  @spec build_config(String.t() | nil, iodata()) :: String.t()
  def build_config(nil, raw_content) do
    EEx.eval_file(@template_tailwind_config_path, assigns: %{raw: IO.iodata_to_binary(raw_content)})
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
