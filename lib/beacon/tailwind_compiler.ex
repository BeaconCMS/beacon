defmodule Beacon.RuntimeCSS.TailwindCompiler do
  @moduledoc """
  Tailwind compiler for runtime CSS, used on all sites.

  The default configuration is fetched from `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js")`,
  you can see the actual file at https://github.com/BeaconCMS/beacon/blob/main/priv/tailwind.config.js

  That's the file used by default if no value is provided in the site configuration `t:Beacon.Config.tailwind_config/0`

  You can use any of the [available options from Tailwind CSS](https://tailwindcss.com/docs/configuration) but
  you must bundle the file if using Plugins or requiring any external module, see the [Tailwind Setup guide](https://hexdocs.pm/beacon/tailwind-setup.html)
  for more info and examples.

  """

  require Logger
  alias Beacon.Content

  @behaviour Beacon.RuntimeCSS

  @impl Beacon.RuntimeCSS
  @spec config(Beacon.Types.Site.t()) :: String.t()
  def config(site) when is_atom(site) do
    site
    |> tailwind_config_path!()
    |> File.read!()
  end

  @doc false
  def css(site) when is_atom(site) do
    site
    |> tailwind_css_path!()
    |> File.read!()
  end

  @impl Beacon.RuntimeCSS
  @spec compile(Beacon.Types.Site.t()) :: {:ok, String.t()} | {:error, any()}
  def compile(site) when is_atom(site) do
    tmp_dir = tmp_dir!()
    config_file_path = generate_tailwind_config_file(site, tmp_dir, beacon_content(tmp_dir))
    templates_path = generate_template_files!(tmp_dir, site)
    input_css_path = generate_input_css_file!(tmp_dir, site)
    output = execute(tmp_dir, config_file_path, input_css_path)
    cleanup(tmp_dir, templates_path)
    {:ok, output}
  end

  defp generate_tailwind_config_file(site, tmp_dir, content) do
    tailwind_config = tailwind_config_path!(site)

    unless Application.get_env(:tailwind, :version) do
      default_tailwind_version = Beacon.tailwind_version()
      Application.put_env(:tailwind, :version, default_tailwind_version)
    end

    Application.put_env(:tailwind, :beacon_runtime, [])

    tailwind_config = """
    const userConfig = require(\"#{tailwind_config}\")

    module.exports = {
      ...userConfig,
      content: [
        <%= @beacon_content %>,
        ...(userConfig.content || [])
      ]
    }
    """

    tailwind_config
    |> EEx.eval_string(assigns: %{beacon_content: content})
    |> write_file!(tmp_dir, "tailwind.config.js")
  end

  defp execute(tmp_dir, config_file_path, input_css_file_path) do
    output_css_path = Path.join(tmp_dir, "generated.css")

    opts =
      if Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev] do
        ~w(
      --config=#{config_file_path}
      --input=#{input_css_file_path}
      --output=#{output_css_path}
    )
      else
        ~w(
      --config=#{config_file_path}
      --input=#{input_css_file_path}
      --output=#{output_css_path}
      --minify
    )
      end

    {cli_output, cli_exit_code} = run_cli(:beacon_runtime, opts)

    output =
      if cli_exit_code == 0 do
        File.read!(output_css_path)
      else
        raise """
          error running tailwind compiler, got exit code: #{cli_exit_code}"

          Tailwind bin path: #{inspect(Tailwind.bin_path())}
          Tailwind bin version: #{inspect(Tailwind.bin_version())}

          Output: #{inspect(cli_output)}
        """
      end

    cleanup(tmp_dir, [config_file_path, input_css_file_path, output_css_path])

    output
  end

  # Run tailwind-cli returning the output and exit code
  # Note that `:cd` is the root dir for regular and umbrella projects so the paths have to be defined accordingly.
  # https://github.com/phoenixframework/tailwind/blob/8cf9810474bf37c1b1dd821503d756885534d2ba/lib/tailwind.ex#L192
  @doc false
  def run_cli(profile, extra_args) when is_atom(profile) and is_list(extra_args) do
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

    if Version.compare(version, "3.3.0") == :lt do
      raise Beacon.LoaderError, """
      Beacon requires Tailwind CSS 3.3.0 or higher.

      Please update your Tailwind CSS binary to the latest version.

      See https://github.com/phoenixframework/tailwind for more info.

      """
    end

    config = Tailwind.config_for!(profile)
    args = config[:args] || []

    opts = [
      cd: File.cwd!(),
      env: config[:env] || %{},
      stderr_to_stdout: true
    ]

    args = args ++ extra_args

    Logger.debug("""
    running Beacon Tailwind Compiler

      bin_path: #{inspect(Tailwind.bin_path())}
      args: #{inspect(args)}
      opts: #{inspect(opts)}

    """)

    System.cmd(Tailwind.bin_path(), args, opts)
  end

  defp tailwind_config_path!(site) do
    tailwind_config = Beacon.Config.fetch!(site).tailwind_config

    if File.exists?(tailwind_config) do
      tailwind_config
    else
      raise """
      Tailwind config not found

      Make sure the provided file exists at #{inspect(tailwind_config)}

      See Beacon.Config for more info.
      """
    end
  end

  defp tailwind_css_path!(site) do
    tailwind_css = Beacon.Config.fetch!(site).tailwind_css

    if File.exists?(tailwind_css) do
      tailwind_css
    else
      raise """
      Tailwind CSS not found

      Make sure the provided file exists at #{inspect(tailwind_css)}

      See Beacon.Config for more info.
      """
    end
  end

  defp generate_template_files!(tmp_dir, site) when is_atom(site) do
    [
      Task.async(fn ->
        Enum.map(Beacon.Content.list_components(site, per_page: :infinity), fn component ->
          component_path = Path.join(tmp_dir, "#{site}_component_#{remove_special_chars(component.name)}.template")
          File.write!(component_path, component.template)
          component_path
        end)
      end),
      Task.async(fn ->
        Enum.map(Content.list_published_layouts(site), fn layout ->
          layout_path = Path.join(tmp_dir, "#{site}_layout_#{remove_special_chars(layout.title)}.template")
          File.write!(layout_path, layout.template)
          layout_path
        end)
      end),
      Task.async(fn ->
        Enum.map(Content.list_published_pages(site, per_page: :infinity), fn page ->
          # TODO: post process variant templates
          variants =
            Enum.reduce(page.variants, "", fn variant, acc ->
              acc <> variant.template
            end)

          page_path = Path.join(tmp_dir, "#{site}_page_#{remove_special_chars(page.path)}.template")
          post_processed_template = Beacon.Lifecycle.Template.load_template(page)
          File.write!(page_path, post_processed_template <> variants)
          page_path
        end)
      end),
      Task.async(fn ->
        Enum.map(Content.list_error_pages(site, per_page: :infinity), fn error_page ->
          error_page_path = Path.join(tmp_dir, "#{site}_error_page_#{error_page.status}.template")
          File.write!(error_page_path, error_page.template)
          error_page_path
        end)
      end)
    ]
    |> Task.await_many(:timer.minutes(4))
    |> List.flatten()
  end

  defp generate_template_files!(tmp_dir, templates) when is_list(templates) do
    Enum.map(templates, fn template ->
      hash = Base.encode16(:crypto.hash(:md5, template), case: :lower)
      template_path = Path.join(tmp_dir, "#{hash}.template")
      File.write!(template_path, template)
      template_path
    end)
  end

  defp generate_input_css_file!(tmp_dir, site) do
    tailwind_css_path = tailwind_css_path!(site)

    beacon_stylesheets =
      site
      |> Beacon.Content.list_stylesheets()
      |> Enum.map_join(fn stylesheet ->
        ["\n", "/* ", stylesheet.name, " */", "\n", stylesheet.content, "\n"]
      end)

    input_css_path = Path.join(tmp_dir, "input.css")
    File.write!(input_css_path, IO.iodata_to_binary([File.read!(tailwind_css_path), "\n", beacon_stylesheets]))
    input_css_path
  end

  defp remove_special_chars(name), do: String.replace(name, ~r/[^[:alnum:]_]+/, "_")

  # include paths for the following scenarios:
  # - regular app
  # - umbrella app running from root
  # - umbrella app running from the web app
  defp beacon_content(tmp_dir) do
    ~s(
    './assets/js/**/*.js',
    './lib/*_web.ex',
    './lib/*_web/**/*.*ex',
    './apps/*_web/assets/**/*.js',
    '!./apps/*_web/assets/node_modules/**',
    './apps/*_web/lib/*_web.ex',
    './apps/*_web/lib/*_web/**/*.*ex',
    '#{tmp_dir}/*.template'
    )
  end

  defp tmp_dir! do
    tmp_dir = Path.join(System.tmp_dir!(), random_dir())
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp write_file!(content, tmp_dir, filename) do
    Logger.debug("""
    writing file #{filename}

    Content:

      #{content}

    """)

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
