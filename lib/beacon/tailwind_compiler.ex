defmodule Beacon.RuntimeCSS.TailwindCompiler do
  @moduledoc """
  Tailwind v4 compiler for runtime CSS.

  Uses `@source inline(...)` to pass template content directly to
  Tailwind and pipes everything through stdin/stdout — zero disk I/O.
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
    templates = collect_all_templates(site)
    output = run_cli(site, templates)
    {:ok, output}
  end

  # ---------------------------------------------------------------------------
  # Template collection — all in memory
  # ---------------------------------------------------------------------------

  defp collect_all_templates(site) do
    [
      collect_component_templates(site),
      collect_layout_templates(site),
      collect_page_templates(site),
      collect_error_page_templates(site)
    ]
    |> Task.await_many(:timer.minutes(4))
    |> IO.iodata_to_binary()
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
  # Input CSS — built in memory, piped to stdin
  # ---------------------------------------------------------------------------

  defp build_input_css(site, _templates, templates_fifo) do
    config = Beacon.Config.fetch!(site)

    [
      "@import \"tailwindcss\" source(none);\n",
      "@source \"#{templates_fifo}\";\n",
      maybe_config_directive(config),
      maybe_user_css(config),
      collect_stylesheets(site)
    ]
    |> IO.iodata_to_binary()
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
  # Tailwind CLI — stdin/stdout, zero disk I/O
  # ---------------------------------------------------------------------------

  defp run_cli(site, templates) do
    check_version!()

    minify? = not (Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev])
    bin = Tailwind.bin_path()
    uid = :erlang.unique_integer([:positive])

    # Two named pipes: templates stay untouched, CSS directives reference the templates FIFO.
    # FIFOs are kernel memory buffers — zero bytes hit disk.
    templates_fifo = Path.join(System.tmp_dir!(), "beacon_tpl_#{uid}")
    input_fifo = Path.join(System.tmp_dir!(), "beacon_css_#{uid}")
    {_, 0} = System.cmd("mkfifo", [templates_fifo])
    {_, 0} = System.cmd("mkfifo", [input_fifo])

    input_css = build_input_css(site, templates, templates_fifo)
    args = if minify?, do: ~w(--input #{input_fifo} --minify), else: ~w(--input #{input_fifo})

    Logger.debug("""
    running Beacon Tailwind Compiler (v4)

      bin_path: #{inspect(bin)}
      input_size: #{byte_size(input_css)} bytes
      templates_size: #{byte_size(templates)} bytes

    """)

    # Writers block until Tailwind opens each FIFO.
    # Tailwind reads input CSS first, sees @source pointing at templates FIFO,
    # then opens and reads the templates.
    input_writer = Task.async(fn -> File.write!(input_fifo, input_css) end)
    templates_writer = Task.async(fn -> File.write!(templates_fifo, templates) end)

    try do
      {output, exit_code} =
        System.cmd(bin, args, cd: File.cwd!(), stderr_to_stdout: true)

      Task.await(input_writer, :timer.minutes(5))
      Task.await(templates_writer, :timer.minutes(5))

      if exit_code == 0 do
        output
      else
        raise """
        error running tailwind compiler, got exit code: #{exit_code}

        Tailwind bin path: #{inspect(bin)}
        Tailwind bin version: #{inspect(Tailwind.bin_version())}

        Output: #{output}
        """
      end
    after
      File.rm(input_fifo)
      File.rm(templates_fifo)
    end
  end

  defp check_version! do
    case Tailwind.bin_version() do
      {:ok, version} ->
        if Version.compare(version, "4.0.0") == :lt do
          raise Beacon.LoaderError, """
          Beacon requires Tailwind CSS 4.0.0 or higher.

          Please update your Tailwind CSS binary to the latest version.

          See https://github.com/phoenixframework/tailwind for more info.

          """
        end

      :error ->
        raise Beacon.LoaderError, """
        tailwind-cli binary not found or the installation is invalid.

        Execute the following command to install the binary used to compile CSS:

            mix tailwind.install

        """
    end
  end

  # Keep run_cli for backwards compatibility (used by tests)
  @doc false
  def run_cli(extra_args) when is_list(extra_args) do
    check_version!()

    opts = [
      cd: File.cwd!(),
      env: %{},
      stderr_to_stdout: true
    ]

    System.cmd(Tailwind.bin_path(), extra_args, opts)
  end
end
