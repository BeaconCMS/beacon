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

  test "move_to_variable/2" do
    module = ~s"""
    import Config

    host = 4000

    config :my_app, foo: :bar
    """

    zipper =
      module
      |> Sourceror.parse_string!()
      |> Sourceror.Zipper.zip()

    assert {:ok, zipper} = Beacon.Igniter.move_to_variable(zipper, :host)

    assert Igniter.Util.Debug.code_at_node(zipper) == "host = 4000"
  end

  describe "move_to_import/2" do
    test "simple module" do
      module = ~s"""
      import Config

      host = 4000

      config :my_app, foo: :bar
      """

      zipper =
        module
        |> Sourceror.parse_string!()
        |> Sourceror.Zipper.zip()

      assert {:ok, zipper} = Beacon.Igniter.move_to_import(zipper, Config)

      assert Igniter.Util.Debug.code_at_node(zipper) == "import Config"
    end

    test "nested module" do
      module = ~s"""
      import Ecto.Query

      def get_user_query(id), do: from(u in "users", where: u.id == ^id)
      """

      zipper =
        module
        |> Sourceror.parse_string!()
        |> Sourceror.Zipper.zip()

      assert {:ok, zipper} = Beacon.Igniter.move_to_import(zipper, Ecto.Query)

      assert Igniter.Util.Debug.code_at_node(zipper) == "import Ecto.Query"
    end

    test "nested module as string" do
      module = ~s"""
      import Ecto.Query

      def get_user_query(id), do: from(u in "users", where: u.id == ^id)
      """

      zipper =
        module
        |> Sourceror.parse_string!()
        |> Sourceror.Zipper.zip()

      assert {:ok, zipper} = Beacon.Igniter.move_to_import(zipper, "Ecto.Query")

      assert Igniter.Util.Debug.code_at_node(zipper) == "import Ecto.Query"
    end
  end
end
