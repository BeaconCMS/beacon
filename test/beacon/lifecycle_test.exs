defmodule Beacon.LifecycleTest do
  use ExUnit.Case, async: true

  alias Beacon.Lifecycle

  describe "execute_steps" do
    setup do
      page = %Beacon.Pages.Page{
        site: :test_lifecycle,
        path: "/test/lifecycle",
        format: :test,
        template: "<div>{ title }</div>"
      }

      [page: page]
    end

    test "step must return :cont or :halt", %{page: page} do
      steps = [my_step: fn _, _ -> :invalid end]

      assert_raise Beacon.LoaderError, ~r/expected step :my_step to return one of the following.*/, fn ->
        assert Lifecycle.execute_steps("load_template", steps, page, %{})
      end
    end

    test "halt with exception", %{page: page} do
      steps = [my_step: fn _template, _metadata -> {:halt, %RuntimeError{message: "halt"}} end]

      assert_raise Beacon.LoaderError, ~r/step :my_step halted with exception.*/, fn ->
        Lifecycle.execute_steps("load_template", steps, page, %{})
      end
    end

    test "reraise loader error", %{page: page} do
      steps = [my_step: fn _template, _metadata -> raise "fail" end]

      assert_raise Beacon.LoaderError, ~r/stage load_template failed with exception.*/, fn ->
        Lifecycle.execute_steps("load_template", steps, page, %{})
      end
    end
  end
end
