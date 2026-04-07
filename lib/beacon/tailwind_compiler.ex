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
    input_css = build_input_css(site, templates)
    output = run_cli_stdin(input_css, site)
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

  defp build_input_css(site, templates) do
    config = Beacon.Config.fetch!(site)

    # Escape quotes in templates for inline source
    escaped = String.replace(templates, "\"", "'")

    [
      "@import \"tailwindcss\" source(none);\n",
      "@source inline(\"", escaped, "\");\n",
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

  defp run_cli_stdin(input_css, _site) do
    check_version!()

    args =
      if Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev] do
        ~w(--input -)
      else
        ~w(--input - --minify)
      end

    Logger.debug("""
    running Beacon Tailwind Compiler (v4)

      bin_path: #{inspect(Tailwind.bin_path())}
      args: #{inspect(args)}
      input_size: #{byte_size(input_css)} bytes

    """)

    port = Port.open({:spawn_executable, Tailwind.bin_path()}, [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      args: args,
      cd: File.cwd!()
    ])

    Port.command(port, input_css)
    Port.command(port, "")
    Port.close(port)

    collect_port_output(port, [])
  end

  defp collect_port_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_port_output(port, [acc, data])

      {^port, {:exit_status, 0}} ->
        IO.iodata_to_binary(acc)

      {^port, {:exit_status, code}} ->
        raise """
        error running tailwind compiler, got exit code: #{code}

        Tailwind bin path: #{inspect(Tailwind.bin_path())}
        Tailwind bin version: #{inspect(Tailwind.bin_version())}

        Output: #{IO.iodata_to_binary(acc)}
        """
    after
      :timer.minutes(5) ->
        raise "Tailwind CLI timed out after 5 minutes"
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
