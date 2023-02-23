defmodule Beacon.TailwindCompiler do
  @moduledoc """
  Tailwind compiler for runtime CSS, used on all sites.

  The default configuration is fetched from `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex")`,
  you can see the actual file at https://github.com/BeaconCMS/beacon/blob/main/priv/tailwind.config.js.eex

  You can provide your own configuration on `Beacon.Router.beacon_site/2` option `:tailwind_config` but note that 2 rules must be followed for your custom config to work properly:

    1. It has to be a [EEx template](https://hexdocs.pm/eex/EEx.html), ie: ends with `.eex`
    2. The [content section](https://tailwindcss.com/docs/content-configuration) needs an entry `<%= @beacon_content %>`, eg:

        ```
        content: [
          <%= @beacon_content %>
        ]
        ```

       You're allowed to include more entries per Tailwind specification, but don't remove that Beacon special placeholder.

  """

  alias Beacon.Components
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  @behaviour Beacon.RuntimeCSS

  @impl Beacon.RuntimeCSS
  def compile!(%Layout{} = layout, opts \\ []) do
    unless Application.get_env(:tailwind, :version) do
      default_tailwind_version = Beacon.tailwind_version()
      Application.put_env(:tailwind, :version, default_tailwind_version)
    end

    Application.put_env(:tailwind, :beacon_runtime, [])

    # TODO: fetch custom config from router if available
    config = build_config(opts[:config_template], raw_content(layout))

    {tmp_dir, config_file} = write_file("tailwind.config.js", config)
    input_css_path = Path.join([Application.app_dir(:beacon), "priv", "beacon.css"])
    output_css_path = Path.join(tmp_dir, "runtime.css")

    exit_code = Tailwind.run(:beacon_runtime, ~w(
      --config=#{config_file}
      --input=#{input_css_path}
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

  @doc false
  def build_config(nil, raw_content) do
    template_tailwind_config_path = Path.join([Application.app_dir(:beacon), "priv", "tailwind.config.js.eex"])
    EEx.eval_file(template_tailwind_config_path, assigns: %{beacon_content: beacon_content(raw_content)})
  end

  def build_config(config_template, raw_content) do
    EEx.eval_string(config_template, assigns: %{beacon_content: beacon_content(raw_content)})
  end

  defp beacon_content(raw_content) do
    ~s(
      'lib/*_web.ex',
      'lib/*_web/**/*.*ex',
      { raw: '#{raw_content}' }
    )
  end

  defp raw_content(layout) do
    page_templates = Pages.list_page_templates_by_layout(layout.id)

    [layout.body, page_templates, Components.list_component_bodies()]
    |> IO.iodata_to_binary()
    |> String.replace("\r", "")
    |> String.replace("\n", "")
    |> String.replace("$", "")
    |> String.replace("`", "")
    |> String.replace("{", "")
    |> String.replace("}", "")
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
