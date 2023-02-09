defmodule Mix.Tasks.Beacon.InstallTest do
  use ExUnit.Case

  alias Ecto.UUID
  alias Mix.Tasks.Beacon.Install

  setup do
    Mix.Task.clear()

    support_path = Path.join([File.cwd!(), "test", "support", "install_files"])
    templates_path = Path.join([File.cwd!(), "priv", "templates"])

    bindings = [
      beacon_site: "my_test_blog",
      ctx_app: :my_app,
      templates_path: templates_path,
      seeds: %{
        path: Path.join([support_path, "seeds.exs"]),
        template_path: Path.join([templates_path, "install", "seeds.exs"])
      },
      router: %{
        path: Path.join([support_path, "dummy_router"]),
        router_scope_template: Path.join([templates_path, "install", "beacon_router_scope.ex"])
      },
      beacon_data_source: %{
        dest_path: Path.join([support_path, "beacon_data_source.ex"]),
        template_path: Path.join([templates_path, "install", "beacon_data_source.ex"]),
        module_name: Module.concat(Beacon, "BeaconDataSource")
      },
      beacon_config: %{
        config_template_path: Path.join([templates_path, "install", "beacon_config.exs"])
      }
    ]

    on_exit(fn ->
      support_path
      |> Path.join("*")
      |> Path.wildcard()
      |> Enum.reject(fn file ->
        Path.basename(file) in ["dummy_router", "dummy_config.exs"]
      end)
      |> Enum.each(&File.rm!/1)
    end)

    [
      bindings: bindings,
      support_path: support_path
    ]
  end

  test "invalid arguments" do
    assert_raise OptionParser.ParseError, ~r/1 error found!\n--invalid-argument : Unknown option/, fn ->
      Install.run(~w(--invalid-argument invalid))
    end
  end

  test "generates seeds file", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:seeds, :path]))
    bindings = put_in(bindings, [:seeds, :path], dest_file)

    seeds_content = EEx.eval_file(get_in(bindings, [:seeds, :template_path]), bindings) |> String.trim_leading()

    Install.maybe_add_seeds(bindings)

    assert File.exists?(dest_file)

    assert File.read!(dest_file) == seeds_content
  end

  test "does not add seeds content twice", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:seeds, :path]))
    bindings = put_in(bindings, [:seeds, :path], dest_file)

    Install.maybe_add_seeds(bindings)

    assert File.exists?(dest_file)
    file_content = File.read!(dest_file)

    Install.maybe_add_seeds(bindings)

    assert file_content == File.read!(dest_file)
  end

  test "adds router content to its file", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:router, :path]))
    bindings = put_in(bindings, [:router, :path], dest_file)

    Install.maybe_add_beacon_scope(bindings)

    assert File.exists?(dest_file)

    file_content = File.read!(dest_file)

    assert file_content =~ ~r/import Beacon\.Router/
    assert file_content =~ ~r/beacon_site \"\/my_test_blog\", name: :my_test_blog/
  end

  test "does not add router content twice or if a beacon config exists", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:router, :path]))

    bindings = put_in(bindings, [:router, :path], dest_file)

    Install.maybe_add_beacon_scope(bindings)

    assert File.exists?(dest_file)

    file_content = File.read!(dest_file)

    Install.maybe_add_beacon_scope(bindings)

    assert file_content == File.read!(dest_file)
  end

  test "adds beacon repo to a config file", %{support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo(test_file)

    assert String.match?(File.read!(test_file), ~r/ecto_repos: \[(.*), Beacon.Repo\]/)
  end

  test "does not add beacon repo twice or ignores if it exists", %{support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo(test_file)

    Install.maybe_add_beacon_repo(test_file)

    refute String.match?(File.read!(test_file), ~r/ecto_repos: \[(.*), Beacon.Repo, Beacon.Repo\]/)
  end

  test "adds beacon repo config to a dev config file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)
    template_file = Path.join([get_in(bindings, [:templates_path]), "install", "beacon_repo_config_dev.exs"])

    repo_config_content = EEx.eval_file(template_file, bindings)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo_config(test_file, bindings)

    assert String.contains?(File.read!(test_file), repo_config_content)
  end

  test "adds beacon repo config to a prod config file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = Path.join([support_path, "prod.exs"])

    template_file = Path.join([get_in(bindings, [:templates_path]), "install", "beacon_repo_config_prod.exs"])

    repo_config_content = EEx.eval_file(template_file, bindings)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo_config(test_file, bindings)

    test_file_content = File.read!(test_file)

    assert String.contains?(test_file_content, repo_config_content)
    refute String.contains?(test_file_content, "stacktrace: true")
  end

  test "does not add beacon repo config twice to a file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo_config(test_file, bindings)

    new_file_content = File.read!(test_file)

    Install.maybe_add_beacon_repo_config(test_file, bindings)

    assert new_file_content == File.read!(test_file)
  end

  test "adds beacon config", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_config(test_file, bindings)

    test_file_content = File.read!(test_file)

    assert String.contains?(test_file_content, "config :beacon, otp_app: :my_app")
    assert test_file_content =~ ~r/sites: \[\n.*my_test_blog: \[\n.*data_source: Beacon.BeaconDataSource/
  end

  test "does not add beacon config twice", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_config(test_file, bindings)

    new_file_content = File.read!(test_file)

    Install.maybe_add_beacon_config(test_file, bindings)

    assert new_file_content == File.read!(test_file)
  end

  test "creates beacon data source file", %{bindings: bindings} do
    dest_path = get_in(bindings, [:beacon_data_source, :dest_path])
    random_path = random_file_name(dest_path, false)
    template_path = get_in(bindings, [:beacon_data_source, :template_path])

    bindings = put_in(bindings, [:beacon_data_source, :dest_path], random_path)
    file_content = EEx.eval_file(template_path, bindings)

    Install.maybe_create_beacon_data_source_file(bindings)

    assert File.read!(random_path) == file_content
  end

  test "does not create a new file if it already exists", %{bindings: bindings} do
    dest_path = get_in(bindings, [:beacon_data_source, :dest_path])
    random_path = random_file_name(dest_path)
    bindings = put_in(bindings, [:beacon_data_source, :dest_path], random_path)

    Install.maybe_create_beacon_data_source_file(bindings)

    assert "" == File.read!(random_path)
  end

  defp random_file_name(path, create_file? \\ true) do
    path_dir = Path.dirname(path)
    path_file = Path.basename(path)

    uuid = UUID.generate()

    file = Path.join([path_dir, "#{uuid}_#{path_file}"])

    if create_file?, do: File.touch!(file)

    file
  end
end
