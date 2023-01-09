defmodule Mix.Tasks.Beacon.Install do
  @shortdoc "Generates beacon base files into the project"

  @moduledoc """

  """
  use Mix.Task

  alias Mix.Tasks.Phx.Gen.Auth.Injector

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

    base_module = Mix.Phoenix.base()
    web_module = Mix.Phoenix.web_module(base_module)
    app_name = Phoenix.Naming.underscore(base_module)

    config_file = config_file("config.exs")
    maybe_add_beacon_repo(config_file, File.read!(config_file))

    dev_config_file = config_file("dev.exs")
    prod_config_file = config_file("prod.exs")

    maybe_add_beacon_repo_config([{dev_config_file, File.read!(dev_config_file)}, {prod_config_file, File.read!(prod_config_file)}])
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

  defp config_file(file_name) do
    if Mix.Phoenix.in_umbrella?(File.cwd!()) do
      Path.expand("../../")
    else
      File.cwd!()
    end
    |> Path.join("config/#{file_name}")
  end
end
