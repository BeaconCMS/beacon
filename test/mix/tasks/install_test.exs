defmodule Mix.Tasks.Beacon.InstallTest do
  use ExUnit.Case

  setup do
    Mix.Task.clear()

    :ok
  end

  test "invalid arguments" do
    assert_raise OptionParser.ParseError, ~r/1 error found!\n--invalid-argument : Unknown option/, fn ->
      Mix.Tasks.Beacon.Install.run(~w(--invalid-argument invalid))
    end
  end
end
