defmodule Mix.Tasks.Beacon.Install do
  @shortdoc "Generates beacon base files into the project"

  @moduledoc """

  """
  use Mix.Task

  @switches [
    beacon_site: :string
  ]

  def run(argv) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix beacon.install can only be run inside an application directory")
    end

    {options, parsed} = OptionParser.parse!(argv, strict: @switches)

    base_module = Mix.Phoenix.base() |> IO.inspect(label: :base)
    web_module = Mix.Phoenix.web_module(base_module)
    app_name = Phoenix.Naming.underscore(base_module)
    config_file = config_file("config.exs") |> File.read!() |> IO.inspect(label: :file)

    maybe_add_beacon_repo(config_file)
  end

  defp maybe_add_beacon_repo(config_file) do
    if !String.contains?(config_file, "Beacon.Repo") do
      regex = ~r/ecto_repos: \[(.*)\]/
      Regex.replace(regex, config_file, "ecto_repos: [\\1, Beacon.Repo]")
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
