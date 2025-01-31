defmodule Beacon.ErrorHandlerTest do
  use ExUnit.Case

  test "enable" do
    Beacon.ErrorHandler.enable(:my_site)
    assert Process.info(self(), :error_handler) == {:error_handler, Beacon.ErrorHandler}
  end

  test "raise on undefined resources" do
    Beacon.ErrorHandler.enable(:nosite)

    assert_raise UndefinedFunctionError, fn ->
      mod = :"Beacon.Web.LiveRenderer.1.Page2"
      mod.page_assigns()
    end
  end
end
