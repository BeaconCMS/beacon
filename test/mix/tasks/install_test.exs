defmodule Mix.Tasks.Beacon.InstallTest do
  use ExUnit.Case

  alias Ecto.UUID
  alias Mix.Tasks.Beacon.Install

  setup do
    Mix.Task.clear()

    support_path = Path.join([File.cwd!(), "test", "support", "install_files"])
    templates_path = Path.join([File.cwd!(), "priv", "templates", "install"])

    bindings = [
      beacon_site: "my_test_blog",
      seeds: %{
        path: Path.join([support_path, "seeds.exs"]),
        template_path: Path.join([templates_path, "seeds.exs"])
      }
    ]

    [
      bindings: bindings
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

    File.rm!(dest_file)
  end

  test "it does not add seeds content twice", %{bindings: bindings} do
    dest_file = random_file_name(get_in(bindings, [:seeds, :path]))
    bindings = put_in(bindings, [:seeds, :path], dest_file)

    Install.maybe_add_seeds(bindings)

    assert File.exists?(dest_file)
    file_content = File.read!(dest_file)

    Install.maybe_add_seeds(bindings)

    assert file_content == File.read!(dest_file)

    File.rm!(dest_file)
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
