defmodule Beacon.TailwindCompiler do
  @moduledoc """
  Tailwind compiler for runtime CSS, used on all sites.

  The default configuration is fetched from `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex")`,
  you can see the actual file at https://github.com/BeaconCMS/beacon/blob/main/priv/tailwind.config.js.eex

    1. It's recommended to be a file ending with .eex

    2. The [content section](https://tailwindcss.com/docs/content-configuration) needs an entry `<%= @beacon_content %>`, eg:

        ```
        content: [
          <%= @beacon_content %>
        ]
        ```

       You're allowed to include more entries per Tailwind specification, but don't remove that special `<%= @beacon_content` placeholder.

  """

  alias Beacon.Components
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  @behaviour Beacon.RuntimeCSS

  @impl Beacon.RuntimeCSS
  def compile!(%Layout{} = layout) do
    config = Beacon.Config.fetch!(layout.site)

    unless Application.get_env(:tailwind, :version) do
      default_tailwind_version = Beacon.tailwind_version()
      Application.put_env(:tailwind, :version, default_tailwind_version)
    end

    Application.put_env(:tailwind, :beacon_runtime, [])

    tmp_dir = tmp_dir!()

    generated_config_file_path =
      config.tailwind_config
      |> EEx.eval_file(assigns: %{beacon_content: beacon_content(layout.id, layout.body)})
      |> write_file!(tmp_dir, "tailwind.config.js")

    input_css_path = Path.join([Application.app_dir(:beacon), "priv", "beacon.css"])

    output_css_path = Path.join(tmp_dir, "generated.css")

    exit_code = Tailwind.run(:beacon_runtime, ~w(
      --config=#{generated_config_file_path}
      --input=#{input_css_path}
      --output=#{output_css_path}
      --minify
      ))

    output =
      if exit_code == 0 do
        File.read!(output_css_path)
      else
        raise "Error running tailwind, got exit code: #{exit_code}"
      end

    cleanup(tmp_dir, [generated_config_file_path, output_css_path])

    output
  end

  defp beacon_content(layout_id, layout_body) do
    raw_content =
      [layout_body, Pages.list_page_templates_by_layout(layout_id), Components.list_component_bodies()]
      |> IO.iodata_to_binary()
      |> String.replace("\r", "")
      |> String.replace("\n", "")
      |> String.replace("$", "")
      |> String.replace("`", "")
      |> String.replace("{", "")
      |> String.replace("}", "")

    ~s('lib/*_web.ex',
    'lib/*_web/**/*.*ex',
    { raw: '#{raw_content}' })
  end

  defp tmp_dir! do
    tmp_dir = Path.join(System.tmp_dir!(), random_dir())
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp write_file!(content, tmp_dir, filename) do
    filepath = Path.join(tmp_dir, filename)
    File.write!(filepath, content)
    filepath
  end

  defp random_dir, do: :crypto.strong_rand_bytes(12) |> Base.encode16()

  defp cleanup(tmp_dir, files) do
    Enum.each(files, &File.rm/1)
    File.rmdir(tmp_dir)
  end
end
