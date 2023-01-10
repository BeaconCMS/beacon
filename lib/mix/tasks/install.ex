defmodule Mix.Tasks.Beacon.Install do
  @shortdoc "Generates beacon base files into the project"

  @moduledoc """

  """
  use Mix.Task

  @switches [
    beacon_site: :string
  ]

  @beacon_repo_config """
  # Configure your Beacon repo
  config :beacon, Beacon.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "my_app_beacon",
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
  """

  @beacon_pipeline """
    pipeline :beacon do
      plug BeaconWeb.Plug
    end
  """

  def run(argv) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix beacon.install can only be run inside an application directory")
    end

    {options, _parsed} = OptionParser.parse!(argv, strict: @switches)

    bindings = build_context_bindings(options)

    # Add Beacon.Repo to config.exs
    config_file = config_file("config.exs")
    maybe_add_beacon_repo(config_file, File.read!(config_file))

    # Add Beacon.Repo database config to dev.exs and prod.exs
    dev_config_file = config_file("dev.exs")
    prod_config_file = config_file("prod.exs")

    maybe_add_beacon_repo_config([{dev_config_file, File.read!(dev_config_file)}, {prod_config_file, File.read!(prod_config_file)}])

    # Create BeaconDataSource file and config
    maybe_create_beacon_data_source_file(bindings)
    maybe_add_beacon_data_source_to_config(config_file, File.read!(config_file), bindings)

    # Add pipeline and scope to router
    maybe_add_beacon_pipeline(bindings)
    maybe_add_beacon_scope(bindings)
  end

  def maybe_add_beacon_scope(bindings) do
    router_file = get_in(bindings, [:router, :path])
    router_file_content = File.read!(router_file)
    router_scope_template = get_in(bindings, [:router, :router_scope_template])
    router_scope_content = EEx.eval_file(router_scope_template, bindings)

    if !String.contains?(router_file_content, "scope \"/\", BeaconWeb do") do
      new_router_content =
        router_file_content
        |> String.trim_trailing()
        |> String.trim_trailing("end")
        |> Kernel.<>(router_scope_content)

      File.write!(router_file, new_router_content)
    end
  end

  defp maybe_add_beacon_pipeline(bindings) do
    router_file = get_in(bindings, [:router, :path])
    router_file_content = File.read!(router_file)

    if !String.contains?(router_file_content, "pipeline :beacon") do
      regex = ~r/(?s)pipeline :([a-z_]+) do\n.*?end/
      new_router_file_content = Regex.replace(regex, router_file_content, "\\0\\2\n\n#{String.trim_trailing(@beacon_pipeline)}\\2", global: false)

      File.write!(router_file, new_router_file_content)
    end
  end

  defp maybe_add_beacon_repo(config_file, config_file_content) do
    if !String.contains?(config_file_content, "Beacon.Repo") do
      regex = ~r/ecto_repos: \[(.*)\]/
      new_config_file_content = Regex.replace(regex, config_file_content, "ecto_repos: [\\1, Beacon.Repo]")

      File.write!(config_file, new_config_file_content)
    end
  end

  defp maybe_add_beacon_repo_config(config_files) when is_list(config_files), do: Enum.map(config_files, &maybe_add_beacon_repo_config/1)

  defp maybe_add_beacon_repo_config({config_file, config_file_content}) do
    if !String.contains?(config_file_content, "config :beacon, Beacon.Repo,") do
      new_config_content = add_to_config(config_file_content, @beacon_repo_config)

      File.write!(config_file, new_config_content)
    end
  end

  defp maybe_add_beacon_data_source_to_config(config_file, config_file_content, bindings) do
    config_content = EEx.eval_file(get_in(bindings, [:beacon_data_source, :config_template_path]), bindings)

    if !String.contains?(config_file_content, config_content) do
      new_config_file_content = add_to_config(config_file_content, config_content)

      File.write!(config_file, new_config_file_content)
    end
  end

  defp maybe_create_beacon_data_source_file(bindings) do
    dest_path = get_in(bindings, [:beacon_data_source, :dest_path])
    template_path = get_in(bindings, [:beacon_data_source, :template_path])

    if !File.exists?(dest_path) do
      File.touch!(dest_path)
      File.write!(dest_path, EEx.eval_file(template_path, bindings))
    end
  end

  defp add_to_config(config_content, data_to_add) do
    Regex.replace(
      ~r/(use Mix\.Config|import Config)(\r\n|\n|$)/,
      config_content,
      "\\0\\2#{String.trim_trailing(data_to_add)}\\2",
      global: false
    )
  end

  defp config_file(file_name) do
    root_path()
    |> Path.join("config/#{file_name}")
  end

  defp root_path do
    if Mix.Phoenix.in_umbrella?(File.cwd!()) do
      Path.expand("../../")
    else
      File.cwd!()
    end
  end

  defp build_context_bindings(options) do
    base_module = Mix.Phoenix.base()
    web_module = Mix.Phoenix.web_module(base_module)
    app_name = Phoenix.Naming.underscore(base_module)
    ctx_app = Mix.Phoenix.context_app()
    lib_path = Mix.Phoenix.context_lib_path(ctx_app, "")
    web_path = Mix.Phoenix.web_path(ctx_app, "")
    templates_path = Path.join([Application.app_dir(:beacon), "priv", "templates"])
    root = root_path()
    beacon_site = Keyword.get(options, :beacon_site, "my_site")

    [
      base_module: base_module,
      web_module: web_module,
      app_name: app_name,
      ctx_app: ctx_app,
      beacon_site: beacon_site,
      beacon_data_source: %{
        dest_path: Path.join([root, lib_path, "beacon_data_source.ex"]),
        template_path: Path.join([templates_path, "install", "beacon_data_source.ex"]),
        config_template_path: Path.join([templates_path, "install", "beacon_data_source_config.exs"]),
        module_name: Module.concat(base_module, "BeaconDataSource")
      },
      router: %{
        path: Path.join([root, web_path, "router.ex"]),
        router_scope_template: Path.join([templates_path, "install", "beacon_router_scope.ex"])
      }
    ]
  end
end
