defmodule Beacon.IgniterTest do
  use ExUnit.Case, async: true

  test "move_to_constant" do
    module = ~s"""
    defmodule Endpoint do
      @session_options [
        store: :cookie,
        key: "_test_key"
      ]
    end
    """

    zipper =
      module
      |> Sourceror.parse_string!()
      |> Sourceror.Zipper.zip()

    assert {:ok, zipper} = Beacon.Igniter.move_to_constant(zipper, :session_options)

    assert Igniter.Util.Debug.code_at_node(zipper) ==
             ~s"""
             @session_options [
               store: :cookie,
               key: "_test_key"
             ]
             """
             |> String.trim()
  end
end
