defmodule Beacon.RuntimeCSS.TailwindCompiler do
  @moduledoc """
  Tailwind v4 compiler for runtime CSS.

  Uses Tailwind's CSS-first configuration with `@source` directives.
  All Beacon templates (pages, layouts, components) are concatenated into
  a single temp file. Tailwind scans it with its own regex extractor —
  no custom class extraction needed.

  The input CSS is generated dynamically:

      @import "tailwindcss" source(none);
      @source "/tmp/beacon_templates.txt";
      @config "/path/to/user/tailwind.config.js";

  `source(none)` disables filesystem scanning. Only the explicit
  `@source` file is scanned. This gives Beacon full control over
  what Tailwind sees.
  """

  require Logger
  alias Beacon.Content

  @behaviour Beacon.RuntimeCSS

  @impl Beacon.RuntimeCSS
  @spec config(Beacon.Types.Site.t()) :: String.t()
  def config(site) when is_atom(site) do
    config = Beacon.Config.fetch!(site)

    if config.tailwind_config && File.exists?(config.tailwind_config) do
      File.read!(config.tailwind_config)
    else
      ""
    end
  end

  @doc false
  def css(site) when is_atom(site) do
    config = Beacon.Config.fetch!(site)

    if config.tailwind_css && File.exists?(config.tailwind_css) do
      File.read!(config.tailwind_css)
    else
      ""
    end
  end

  @impl Beacon.RuntimeCSS
  @spec compile(Beacon.Types.Site.t()) :: {:ok, String.t()} | {:error, any()}
  def compile(site) when is_atom(site) do
    tmp_dir = tmp_dir!()

    templates_path = write_combined_templates!(tmp_dir, site)
    input_css_path = generate_input_css!(tmp_dir, site, templates_path)
    output = execute(tmp_dir, input_css_path)
    cleanup(tmp_dir, [templates_path, input_css_path])

    {:ok, output}
  end

  # ---------------------------------------------------------------------------
  # Combined template file — ONE file with all Beacon content
  # ---------------------------------------------------------------------------

  defp write_combined_templates!(tmp_dir, site) do
    templates_path = Path.join(tmp_dir, "beacon_templates.txt")

    content =
      [
        collect_component_templates(site),
        collect_layout_templates(site),
        collect_page_templates(site),
        collect_error_page_templates(site)
      ]
      |> Task.await_many(:timer.minutes(4))
      |> IO.iodata_to_binary()

    File.write!(templates_path, content)
    templates_path
  end

  defp collect_component_templates(site) do
    Task.async(fn ->
      Content.list_components(site, per_page: :infinity)
      |> Enum.map(fn c -> ["\n", c.template] end)
    end)
  end

  defp collect_layout_templates(site) do
    Task.async(fn ->
      Content.list_published_layouts(site)
      |> Enum.map(fn l -> ["\n", l.template] end)
    end)
  end

  defp collect_page_templates(site) do
    Task.async(fn ->
      Content.list_published_pages_snapshot_data(site)
      |> Enum.map(fn p ->
        template = Beacon.Lifecycle.Template.load_template(p)
        ["\n", template]
      end)
    end)
  end

  defp collect_error_page_templates(site) do
    Task.async(fn ->
      Content.list_error_pages(site, per_page: :infinity)
      |> Enum.map(fn e -> ["\n", e.template] end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Input CSS generation — Tailwind v4 CSS-first config
  # ---------------------------------------------------------------------------

  defp generate_input_css!(tmp_dir, site, templates_path) do
    config = Beacon.Config.fetch!(site)

    # Build the CSS input with @source directives
    parts = [
      "@import \"tailwindcss\" source(none);\n",
      "@source \"#{templates_path}\";\n",
      host_app_sources(),
      maybe_config_directive(config),
      maybe_user_css(config),
      collect_stylesheets(site)
    ]

    input_css_path = Path.join(tmp_dir, "input.css")
    File.write!(input_css_path, IO.iodata_to_binary(parts))
    input_css_path
  end

  # Scan host app files for classes used in Phoenix components/views
  defp host_app_sources do
    paths = [
      "./assets/js/**/*.js",
      "./lib/*_web.ex",
      "./lib/*_web/**/*.*ex",
      "./apps/*_web/assets/**/*.js",
      "!./apps/*_web/assets/node_modules/**",
      "./apps/*_web/lib/*_web.ex",
      "./apps/*_web/lib/*_web/**/*.*ex"
    ]

    Enum.map_join(paths, fn path -> "@source \"#{path}\";\n" end)
  end

  defp maybe_config_directive(config) do
    if config.tailwind_config && File.exists?(config.tailwind_config) do
      "@config \"#{config.tailwind_config}\";\n"
    else
      ""
    end
  end

  defp maybe_user_css(config) do
    if config.tailwind_css && File.exists?(config.tailwind_css) do
      css = File.read!(config.tailwind_css)
      # Strip v3 directives — they're replaced by @import "tailwindcss"
      css
      |> String.replace(~r/@tailwind\s+(base|components|utilities)\s*;/, "")
      |> String.replace(~r/@import\s+"tailwindcss[^"]*"\s*;/, "")
      |> then(&["\n", &1, "\n"])
    else
      ""
    end
  end

  defp collect_stylesheets(site) do
    site
    |> Content.list_stylesheets()
    |> Enum.map(fn s -> ["\n/* ", s.name, " */\n", s.content, "\n"] end)
  end

  # ---------------------------------------------------------------------------
  # Tailwind CLI execution
  # ---------------------------------------------------------------------------

  defp execute(tmp_dir, input_css_path) do
    output_css_path = Path.join(tmp_dir, "generated.css")

    opts =
      if Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev] do
        ~w(--input #{input_css_path} --output #{output_css_path})
      else
        ~w(--input #{input_css_path} --output #{output_css_path} --minify)
      end

    {cli_output, cli_exit_code} = run_cli(opts)

    output =
      if cli_exit_code == 0 do
        File.read!(output_css_path)
      else
        raise """
        error running tailwind compiler, got exit code: #{cli_exit_code}

        Tailwind bin path: #{inspect(Tailwind.bin_path())}
        Tailwind bin version: #{inspect(Tailwind.bin_version())}

        Output: #{inspect(cli_output)}
        """
      end

    cleanup(tmp_dir, [output_css_path])
    output
  end

  @doc false
  def run_cli(extra_args) when is_list(extra_args) do
    version =
      case Tailwind.bin_version() do
        {:ok, version} ->
          version

        :error ->
          raise Beacon.LoaderError, """
          tailwind-cli binary not found or the installation is invalid.

          Execute the following command to install the binary used to compile CSS:

              mix tailwind.install

          """
      end

    if Version.compare(version, "4.0.0") == :lt do
      raise Beacon.LoaderError, """
      Beacon requires Tailwind CSS 4.0.0 or higher.

      Please update your Tailwind CSS binary to the latest version.

      See https://github.com/phoenixframework/tailwind for more info.

      """
    end

    opts = [
      cd: File.cwd!(),
      env: %{},
      stderr_to_stdout: true
    ]

    args = extra_args

    Logger.debug("""
    running Beacon Tailwind Compiler (v4)

      bin_path: #{inspect(Tailwind.bin_path())}
      args: #{inspect(args)}

    """)

    System.cmd(Tailwind.bin_path(), args, opts)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp tmp_dir! do
    tmp_dir = Path.join(System.tmp_dir!(), random_dir())
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp random_dir, do: :crypto.strong_rand_bytes(12) |> Base.encode16()

  defp cleanup(tmp_dir, files) do
    Enum.each(files, &File.rm/1)
    File.rmdir(tmp_dir)
  end
end
