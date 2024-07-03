# credo:disable-for-this-file Credo.Check.Warning.UnusedPathOperation
defmodule Mix.Tasks.Beacon.Install do
  @shortdoc "Generates beacon base files into the project"

  @moduledoc """
  Generates beacon necessary configurations.

  Before running this command, make sure you commited all your changes to git,
  beacuse it generates new files and modifies existing ones.

    $ mix beacon.install --site blog

  The argument `site` defines the name of your beacon site and is
  used to generate the necessary configuration files.

  ## Arguments

    * `--site` (required) - The name of your beacon site.
  """
  use Mix.Task

  @switches [
    site: :string,
    path: :string
  ]

  def run(argv) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix beacon.install can only be run inside an application directory")
    end

    {options, _parsed} = OptionParser.parse!(argv, strict: @switches)

    bindings = build_context_bindings(options)

    config_file_path = config_file_path("config.exs")
    inject_endpoint_render_errors_config(config_file_path)

    maybe_inject_beacon_site_routes(bindings)

    maybe_inject_beacon_supervisor(bindings)

    Mix.shell().info("""

      A new site has been configured at #{bindings[:path]}

      Please check out the guides for more info:

        * https://github.com/BeaconCMS/beacon/tree/main/guides
        * https://github.com/BeaconCMS/beacon_live_admin/tree/main/guides

      Adjust the configuration as needed and run:

          $ mix setup

      And then start your Phoenix app:

          $ mix phx.server

      Note that the generator changes existing files which may not be formatted correctly, please run `mix format` if needed.

    """)
  end

  @doc false
  def inject_endpoint_render_errors_config(config_file_path) do
    config_file_content = File.read!(config_file_path)

    if String.contains?(config_file_content, "BeaconWeb.ErrorHTML") do
      Mix.shell().info([
        :yellow,
        "* skip ",
        :reset,
        "injecting Beacon.ErrorHTML to render_errors into ",
        Path.relative_to_cwd(config_file_path),
        " (already exists)"
      ])
    else
      regex = ~r/(config.*\.Endpoint,\n)((?:.+\n)*\s*)\n/

      [_header, endpoint_config_str] = Regex.run(regex, config_file_content, capture: :all_but_first)
      {config_list, []} = Code.eval_string("[" <> endpoint_config_str <> "]")
      updated_config_list = put_in(config_list, [:render_errors, :formats, :html], BeaconWeb.ErrorHTML)

      updated_str = inspect(updated_config_list) <> "\n"

      new_config_file_content =
        regex
        |> Regex.replace(config_file_content, "\\1#{updated_str}")
        |> Code.format_string!(file: config_file_path)

      File.write!(config_file_path, [new_config_file_content, "\n"])
    end
  end

  defp config_file_path(file_name) do
    Path.join(root_path(), "config/#{file_name}")
  end

  @doc false
  def maybe_inject_beacon_site_routes(bindings) do
    router_file = get_in(bindings, [:router, :path])
    router_file_content = File.read!(router_file)
    router_scope_template = get_in(bindings, [:router, :router_scope_template])
    router_scope_content = EEx.eval_file(router_scope_template, bindings)

    if String.contains?(router_file_content, "beacon_site \"") do
      Mix.shell().info([:yellow, "* skip ", :reset, "injecting beacon scope into ", Path.relative_to_cwd(router_file), " (already exists)"])
    else
      new_router_content =
        router_file_content
        |> String.trim_trailing()
        |> String.trim_trailing("end")
        |> Kernel.<>(router_scope_content)
        |> Kernel.<>("end\n")

      Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(router_file)])
      File.write!(router_file, new_router_content)
    end
  end

  @doc false
  def maybe_inject_beacon_supervisor(bindings) do
    application_file = get_in(bindings, [:application, :path])
    application_file_content = File.read!(application_file)

    if String.contains?(application_file_content, "{Beacon,") do
      Mix.shell().info([:yellow, "* skip ", :reset, "injecting beacon supervisor into ", Path.relative_to_cwd(application_file), " (already exists)"])
    else
      site = bindings[:site]
      repo = [bindings[:base_module], "Repo"] |> Module.concat() |> inspect()
      endpoint = bindings |> get_in([:endpoint, :module_name]) |> inspect()
      router = bindings |> get_in([:router, :module_name]) |> inspect()

      new_application_file_content =
        application_file_content
        |> String.replace(".Endpoint\n", ".Endpoint,\n")
        |> String.replace(~r/(children = [^]]*)]/, "\\1 {Beacon, sites: [[site: :#{site}, repo: #{repo}, endpoint: #{endpoint}, router: #{router}]]}\n]")

      Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(application_file)])
      File.write!(application_file, new_application_file_content)
    end
  end

  defp root_path do
    if Mix.Phoenix.in_umbrella?(File.cwd!()) do
      Path.expand("../../")
    else
      File.cwd!()
    end
  end

  defp build_context_bindings(options) do
    options =
      options
      |> add_default_options_if_missing()
      |> validate_options!()

    base_module = Mix.Phoenix.base()
    web_module = Mix.Phoenix.web_module(base_module)
    app_name = Phoenix.Naming.underscore(base_module)
    ctx_app = Mix.Phoenix.context_app()
    lib_path = Mix.Phoenix.context_lib_path(ctx_app, "")
    web_path = Mix.Phoenix.web_path(ctx_app, "")
    templates_path = Path.join([Application.app_dir(:beacon), "priv", "templates"])
    root = root_path()
    site = Keyword.get(options, :site)
    path = Keyword.get(options, :path)

    [
      base_module: base_module,
      web_module: web_module,
      app_name: app_name,
      ctx_app: ctx_app,
      templates_path: templates_path,
      site: site,
      path: path,
      endpoint: %{
        module_name: Module.concat(web_module, "Endpoint")
      },
      router: %{
        path: Path.join([root, web_path, "router.ex"]),
        router_scope_template: Path.join([templates_path, "install", "beacon_router_scope.ex"]),
        module_name: Module.concat(web_module, "Router")
      },
      application: %{
        path: Path.join([root, lib_path, "application.ex"])
      },
      mix: %{
        path: Path.join([root, "mix.exs"])
      }
    ]
  end

  @dialyzer {:no_return, raise_with_help!: 1}
  defp raise_with_help!(msg) do
    Mix.raise("""
    #{msg}

    mix beacon.install expect a site name, for example:

        mix beacon.install --site blog
        or
        mix beacon.install --site blog --path "/blog_path"
    """)
  end

  defp validate_options!([] = _options) do
    raise_with_help!("Missing arguments.")
  end

  defp validate_options!(options) do
    cond do
      !Beacon.Types.Site.valid?(options[:site]) -> raise_with_help!("Invalid site name. It should not contain special characters.")
      !Beacon.Types.Site.valid_name?(options[:site]) -> raise_with_help!("Invalid site name. The site name can't start with \"beacon_\".")
      !Beacon.Types.Site.valid_path?(options[:path]) -> raise_with_help!("Invalid path value. The path value have to start with /.")
      :default -> options
    end
  end

  defp add_default_options_if_missing(options) do
    defaults =
      @switches
      |> Keyword.keys()
      |> Enum.reduce([], fn
        :path, acc ->
          site = Keyword.get(options, :site)
          [{:path, "/#{site}"} | acc]

        _key, acc ->
          acc
      end)

    Keyword.merge(defaults, options)
  end
end
