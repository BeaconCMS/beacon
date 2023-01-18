defmodule Mix.Tasks.Beacon.Install do
  @shortdoc "Generates beacon base files into the project"

  @moduledoc """
  Generates beacon necessary configurations.

  Before running this command, make sure you commited all your changes to git,
  beacuse it generates new files and modifies existing ones.

    $ mix beacon.install --beacon-site "my-beacon-site"

  The argument `beacon-site` defines the name of your beacon site and is
  used to generate the necessary configuration files, defaults to `my-site`.

  ## Arguments

    * `--beacon-site` - The name of your beacon site, defaults to `my-site`
  """
  use Mix.Task

  @switches [
    beacon_site: :string
  ]

  def run(argv) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix beacon.install can only be run inside an application directory")
    end

    {options, _parsed} = OptionParser.parse!(argv, strict: @switches)

    bindings = build_context_bindings(options)

    # Add Beacon.Repo to config.exs
    config_file = config_file("config.exs")
    maybe_add_beacon_repo(config_file)

    # Add Beacon.Repo database config to dev.exs and prod.exs
    dev_config_file = config_file("dev.exs")
    prod_config_file = config_file("prod.exs")

    maybe_add_beacon_repo_config(dev_config_file, bindings)
    maybe_add_beacon_repo_config(prod_config_file, bindings)

    # Create BeaconDataSource file and config
    maybe_create_beacon_data_source_file(bindings)
    maybe_add_beacon_data_source_to_config(config_file, File.read!(config_file), bindings)

    # Add pipeline and scope to router
    maybe_add_beacon_scope(bindings)

    # Add seeds content
    maybe_add_seeds(bindings)
  end

  @doc false
  def maybe_add_seeds(bindings) do
    seeds_path = get_in(bindings, [:seeds, :path])
    template_path = get_in(bindings, [:seeds, :template_path])

    File.mkdir_p!(Path.dirname(seeds_path))
    File.touch!(seeds_path)

    seeds_content = EEx.eval_file(template_path, bindings)
    seeds_file_content = File.read!(seeds_path)

    if !Enum.any?(
         ["Stylesheets.create_stylesheet!", "Components.create_component!", "Layouts.create_layout!", "Pages.create_page!"],
         &String.contains?(seeds_file_content, &1)
       ) do
      new_seeds_content =
        seeds_file_content
        |> String.trim_trailing()
        |> Kernel.<>(seeds_content)
        |> String.trim_leading()

      File.write!(seeds_path, new_seeds_content)
    end
  end

  @doc false
  def maybe_add_beacon_scope(bindings) do
    router_file = get_in(bindings, [:router, :path])
    router_file_content = File.read!(router_file)
    router_scope_template = get_in(bindings, [:router, :router_scope_template])
    router_scope_content = EEx.eval_file(router_scope_template, bindings)

    if !String.contains?(router_file_content, "beacon_site \"") do
      new_router_content =
        router_file_content
        |> String.trim_trailing()
        |> String.trim_trailing("end")
        |> Kernel.<>(router_scope_content)
        |> Kernel.<>("end\n")

      File.write!(router_file, new_router_content)
    end
  end

  @doc false
  def maybe_add_beacon_repo(config_file) do
    config_file_content = File.read!(config_file)

    if !String.contains?(config_file_content, "Beacon.Repo") do
      regex = ~r/ecto_repos: \[(.*)\]/
      new_config_file_content = Regex.replace(regex, config_file_content, "ecto_repos: [\\1, Beacon.Repo]")

      File.write!(config_file, new_config_file_content)
    end
  end

  defp maybe_add_beacon_repo_config(config_file, bindings) do
    config_file_content = File.read!(config_file)
    templates_path = get_in(bindings, [:templates_path])
    beacon_repo_config = EEx.eval_file(Path.join([templates_path, "install", "beacon_repo_config.exs"]), bindings)

    if !String.contains?(config_file_content, beacon_repo_config) do
      new_config_content = add_to_config(config_file_content, beacon_repo_config)

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
      templates_path: templates_path,
      beacon_data_source: %{
        dest_path: Path.join([root, lib_path, "beacon_data_source.ex"]),
        template_path: Path.join([templates_path, "install", "beacon_data_source.ex"]),
        config_template_path: Path.join([templates_path, "install", "beacon_data_source_config.exs"]),
        module_name: Module.concat(base_module, "BeaconDataSource")
      },
      router: %{
        path: Path.join([root, web_path, "router.ex"]),
        router_scope_template: Path.join([templates_path, "install", "beacon_router_scope.ex"])
      },
      seeds: %{
        path: Path.join([root, "priv", "repo", "seeds.exs"]),
        template_path: Path.join([templates_path, "install", "seeds.exs"])
      }
    ]
  end
end
