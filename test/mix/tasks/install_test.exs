defmodule Mix.Tasks.Beacon.InstallTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  alias Ecto.UUID
  alias Mix.Tasks.Beacon.Install

  defp random_file_name(path, create_file? \\ true) do
    path_dir = Path.dirname(path)
    path_file = Path.basename(path)

    uuid = UUID.generate()

    file = Path.join([path_dir, "#{uuid}_#{path_file}"])

    if create_file?, do: File.touch!(file)

    file
  end

  setup do
    Mix.Task.clear()

    support_path = Path.join([File.cwd!(), "test", "support", "install_files"])
    templates_path = Path.join([File.cwd!(), "priv", "templates"])

    bindings = [
      app_name: "my_test",
      site: "my_test_blog",
      ctx_app: :my_app,
      templates_path: templates_path,
      seeds: %{
        path: Path.join([support_path, "seeds.exs"]),
        template_path: Path.join([templates_path, "install", "seeds.exs"])
      },
      router: %{
        path: Path.join([support_path, "dummy_router"]),
        router_scope_template: Path.join([templates_path, "install", "beacon_router_scope.ex"]),
        module_name: Module.concat(DummyAppWeb, "Router")
      },
      application: %{
        path: Path.join([support_path, "dummy_application"])
      },
      beacon_data_source: %{
        dest_path: Path.join([support_path, "beacon_data_source.ex"]),
        template_path: Path.join([templates_path, "install", "beacon_data_source.ex"]),
        module_name: Module.concat(DummyApp, "BeaconDataSource")
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

  test "creates seeds file", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:seeds, :path]))
    bindings = put_in(bindings, [:seeds, :path], dest_file)

    seeds_content = EEx.eval_file(get_in(bindings, [:seeds, :template_path]), bindings) |> String.trim_leading()

    capture_io(fn ->
      Install.maybe_create_beacon_seeds(bindings)

      assert File.exists?(dest_file)
      assert File.read!(dest_file) == seeds_content
    end)
  end

  test "does not create beacon seeds twice", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:seeds, :path]))
    bindings = put_in(bindings, [:seeds, :path], dest_file)

    capture_io(fn ->
      Install.maybe_create_beacon_seeds(bindings)

      file_content = File.read!(dest_file)

      Install.maybe_create_beacon_seeds(bindings)

      assert file_content == File.read!(dest_file)
    end)
  end

  test "adds router content to its file", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:router, :path]))
    bindings = put_in(bindings, [:router, :path], dest_file)

    capture_io(fn ->
      Install.maybe_inject_beacon_site_routes(bindings)

      file_content = File.read!(dest_file)
      assert file_content =~ ~r/use Beacon\.Router/
      assert file_content =~ ~r/beacon_site \"\/my_test_blog\", site: :my_test_blog/
    end)
  end

  test "does not add router content twice or if a beacon config exists", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:router, :path]))

    bindings = put_in(bindings, [:router, :path], dest_file)

    capture_io(fn ->
      Install.maybe_inject_beacon_site_routes(bindings)

      file_content = File.read!(dest_file)

      Install.maybe_inject_beacon_site_routes(bindings)

      assert file_content == File.read!(dest_file)
    end)
  end

  test "injects beacon repo injeto ecto_repos", %{support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    capture_io(fn ->
      Install.maybe_inject_beacon_repo_into_ecto_repos(test_file)
      assert String.match?(File.read!(test_file), ~r/ecto_repos: \[(.*), Beacon.Repo\]/)
    end)
  end

  test "does not inject beacon repo into ecto_repos twice or ignores if it exists", %{support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    capture_io(fn ->
      Install.maybe_inject_beacon_repo_into_ecto_repos(test_file)
      Install.maybe_inject_beacon_repo_into_ecto_repos(test_file)

      refute String.match?(File.read!(test_file), ~r/ecto_repos: \[(.*), Beacon.Repo, Beacon.Repo\]/)
    end)
  end

  test "adds beacon repo config to a dev config file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)
    template_file = Path.join([get_in(bindings, [:templates_path]), "install", "beacon_repo_config_dev.exs"])

    repo_config_content = EEx.eval_file(template_file, bindings)

    File.cp!(config_file, test_file)

    capture_io(fn ->
      Install.maybe_inject_beacon_repo_config(test_file, bindings)

      assert String.contains?(File.read!(test_file), repo_config_content)
    end)
  end

  test "injects beacon repo config to a prod config file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = Path.join([support_path, "prod.exs"])

    template_file = Path.join([get_in(bindings, [:templates_path]), "install", "beacon_repo_config_prod.exs"])

    repo_config_content = EEx.eval_file(template_file, bindings)

    File.cp!(config_file, test_file)

    capture_io(fn ->
      Install.maybe_inject_beacon_repo_config(test_file, bindings)

      test_file_content = File.read!(test_file)

      assert String.contains?(test_file_content, repo_config_content)
      refute String.contains?(test_file_content, "stacktrace: true")
    end)
  end

  test "does not inject beacon repo config twice to a file", %{bindings: bindings, support_path: support_path} do
    config_file = Path.join([support_path, "dummy_config.exs"])
    test_file = random_file_name(config_file)

    File.cp!(config_file, test_file)

    capture_io(fn ->
      Install.maybe_inject_beacon_repo_config(test_file, bindings)

      new_file_content = File.read!(test_file)

      Install.maybe_inject_beacon_repo_config(test_file, bindings)

      assert new_file_content == File.read!(test_file)
    end)
  end

  test "creates beacon data source file", %{bindings: bindings} do
    dest_path = get_in(bindings, [:beacon_data_source, :dest_path])
    random_path = random_file_name(dest_path, false)
    template_path = get_in(bindings, [:beacon_data_source, :template_path])

    bindings = put_in(bindings, [:beacon_data_source, :dest_path], random_path)
    file_content = EEx.eval_file(template_path, bindings)

    capture_io(fn ->
      Install.maybe_create_beacon_data_source_file(bindings)

      assert File.read!(random_path) == file_content
    end)
  end

  test "does not create a new file if it already exists", %{bindings: bindings} do
    dest_path = get_in(bindings, [:beacon_data_source, :dest_path])
    random_path = random_file_name(dest_path)
    bindings = put_in(bindings, [:beacon_data_source, :dest_path], random_path)

    capture_io(fn ->
      Install.maybe_create_beacon_data_source_file(bindings)

      assert "" == File.read!(random_path)
    end)
  end

  describe "maybe_inject_beacon_supervisor" do
    def write_application_file(%{bindings: bindings}) do
      application_file_template = ~S"""
      defmodule MyApp.Application do
        use Application

        @impl true
        def start(_type, _args) do
          children = [
            # Start the Ecto repository
            MyApp.Repo,
            MyAppWeb.Endpoint
            # Start a worker by calling: MyApp.Worker.start_link(arg)
            # {MyApp.Worker, arg}
         ]
          opts = [strategy: :one_for_one, name: MyApp.Supervisor]
          Supervisor.start_link(children, opts)
        end

        @impl true
        def config_change(changed, _new, removed) do
          MyAppWeb.Endpoint.config_change(changed, removed)
          :ok
        end
      end
      """

      application_file_path = get_in(bindings, [:application, :path])
      File.write!(application_file_path, application_file_template)
    end

    setup :write_application_file

    test "does not inject if it already exists", %{bindings: bindings} do
      output =
        capture_io(fn ->
          Install.maybe_inject_beacon_supervisor(bindings)
          Install.maybe_inject_beacon_supervisor(bindings)
        end)

      assert output =~ ~r/injecting beacon supervisor into.*dummy_application/
      assert output =~ ~r/skip.*injecting beacon supervisor/
    end

    test "append comma after endpoint", %{bindings: bindings} do
      application_file_path = get_in(bindings, [:application, :path])

      capture_io(fn ->
        Install.maybe_inject_beacon_supervisor(bindings)
        assert File.read!(application_file_path) =~ "MyAppWeb.Endpoint,"
      end)
    end

    test "append beacon supervisor at end of list", %{bindings: bindings} do
      application_file_path = get_in(bindings, [:application, :path])

      capture_io(fn ->
        Install.maybe_inject_beacon_supervisor(bindings)

        assert File.read!(application_file_path) =~
                 ~r/{Beacon, sites: \[\[site: :my_test_blog, router: DummyAppWeb.Router, data_source: DummyApp.BeaconDataSource\]\]}\n.*\]/
      end)
    end
  end
end
