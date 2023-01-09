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

  def run(argv) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix beacon.install can only be run inside an application directory")
    end

    {options, parsed} = OptionParser.parse!(argv, strict: @switches)

    bindings = build_context_bindings() |> IO.inspect(label: :bindings)

    # Add Beacon.Repo to config.exs
    config_file = config_file("config.exs")
    maybe_add_beacon_repo(config_file, File.read!(config_file))

    # Add Beacon.Repo database config to dev.exs and prod.exs
    dev_config_file = config_file("dev.exs")
    prod_config_file = config_file("prod.exs")

    maybe_add_beacon_repo_config([{dev_config_file, File.read!(dev_config_file)}, {prod_config_file, File.read!(prod_config_file)}])

    # Create BeaconDataSource file
    maybe_create_beacon_data_source_file(bindings)
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
      new_config_content =
        Regex.replace(
          ~r/(use Mix\.Config|import Config)(\r\n|\n|$)/,
          config_file_content,
          "\\0\\2#{String.trim_trailing(@beacon_repo_config)}\\2",
          global: false
        )

      File.write!(config_file, new_config_content)
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

  defp build_context_bindings do
    base_module = Mix.Phoenix.base()
    web_module = Mix.Phoenix.web_module(base_module)
    app_name = Phoenix.Naming.underscore(base_module)
    ctx_app = Mix.Phoenix.context_app()
    lib_path = Mix.Phoenix.context_lib_path(ctx_app, "")
    templates_path = Mix.Phoenix.context_app_path(ctx_app, "priv/templates")
    root = root_path()

    [
      base_module: base_module,
      web_module: web_module,
      app_name: app_name,
      ctx_app: ctx_app,
      beacon_data_source: [
        dest_path: Path.join([root, lib_path, "beacon_data_source.ex"]),
        template_path: Path.join([root, templates_path, "install/beacon_data_source.ex"]),
        module_name: Module.concat(base_module, "BeaconDataSource")
      ]
    ]
  end
end
