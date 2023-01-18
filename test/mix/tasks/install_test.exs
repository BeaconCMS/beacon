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
      templates_path: templates_path,
      seeds: %{
        path: Path.join([support_path, "seeds.exs"]),
        template_path: Path.join([templates_path, "install", "seeds.exs"])
      },
      router: %{
        path: Path.join([support_path, "router_test"]),
        router_scope_template: Path.join([templates_path, "install", "beacon_router_scope.ex"])
      },
      beacon_data_source: %{
        dest_path: Path.join([support_path, "beacon_data_source.ex"]),
        template_path: Path.join([templates_path, "beacon_data_source.ex"]),
        config_template_path: Path.join([templates_path, "install", "beacon_data_source_config.exs"]),
        module_name: Module.concat(Beacon, "BeaconDataSource")
      }
    ]

    on_exit(fn ->
      support_path
      |> Path.join("*")
      |> Path.wildcard()
      |> Enum.reject(fn file ->
        Path.basename(file) in ["router_test", "config_test.exs"]
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
      Mix.Tasks.Beacon.Install.run(~w(--invalid-argument invalid))
    end
  end

  test "it generates seeds file", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:seeds, :path]))
    bindings = put_in(bindings, [:seeds, :path], dest_file)

    seeds_content = EEx.eval_file(get_in(bindings, [:seeds, :template_path]), bindings) |> String.trim_leading()

    Install.maybe_add_seeds(bindings)

    assert File.exists?(dest_file)

    assert File.read!(dest_file) == seeds_content
  end

  test "it does not add seeds content twice", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:seeds, :path]))
    bindings = put_in(bindings, [:seeds, :path], dest_file)

    Install.maybe_add_seeds(bindings)

    assert File.exists?(dest_file)
    file_content = File.read!(dest_file)

    Install.maybe_add_seeds(bindings)

    assert file_content == File.read!(dest_file)
  end

  test "it adds router content to its file", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:router, :path]))
    bindings = put_in(bindings, [:router, :path], dest_file)

    Install.maybe_add_beacon_scope(bindings)

    assert File.exists?(dest_file)

    file_content = File.read!(dest_file)

    assert file_content =~ ~r/import Beacon\.Router/
    assert file_content =~ ~r/beacon_site \"\/my_test_blog\"/
    assert file_content =~ ~r/name: \"my_test_blog\"/
    assert file_content =~ ~r/data_source: Beacon.BeaconDataSource/
  end

  test "it does not add router content twice or if a beacon config exists", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:router, :path]))
    bindings = put_in(bindings, [:router, :path], dest_file)

    Install.maybe_add_beacon_scope(bindings)

    assert File.exists?(dest_file)

    file_content = File.read!(dest_file)

    Install.maybe_add_beacon_scope(bindings)

    assert file_content == File.read!(dest_file)
  end

  test "it adds beacon repo to a config file", %{support_path: support_path} do
    config_file = Path.join([support_path, "config_test.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo(test_file)

    assert String.match?(File.read!(test_file), ~r/ecto_repos: \[(.*), Beacon.Repo\]/)
  end

  test "it does not add beacon repo twice or ignores if it exists", %{support_path: support_path} do
    config_file = Path.join([support_path, "config_test.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo(test_file)

    Install.maybe_add_beacon_repo(test_file)

    refute String.match?(File.read!(test_file), ~r/ecto_repos: \[(.*), Beacon.Repo, Beacon.Repo\]/)
  end

  test "it adds beacon repo config to a config file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "config_test.exs"])
    test_file = random_file_name(config_file)
    template_file = Path.join([get_in(bindings, [:templates_path]), "install", "beacon_repo_config.exs"])

    repo_config_content = EEx.eval_file(template_file, bindings)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo_config(test_file, bindings)

    assert String.contains?(File.read!(test_file), repo_config_content)
  end

  test "it does not add beacon repo config twice to a file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "config_test.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    Install.maybe_add_beacon_repo_config(test_file, bindings)

    new_file_content = File.read!(test_file)

    Install.maybe_add_beacon_repo_config(test_file, bindings)

    assert new_file_content == File.read!(test_file)
  end

  defp random_file_name(path) do
    path_dir = Path.dirname(path)
    path_file = Path.basename(path)

    uuid = UUID.generate()

    file = Path.join([path_dir, "#{uuid}_#{path_file}"])

    File.touch!(file)

    file
  end
end
