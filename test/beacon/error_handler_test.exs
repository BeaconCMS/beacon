# defmodule Beacon.ErrorHandlerTest do
#   use ExUnit.Case

#   test "error handler" do
#     Process.flag(:error_handler, Beacon.ErrorHandler)

#     assert_raise UndefinedFunctionError, fn ->
#       mod = :"Elixir.Module.Fake"
#       mod.page_assigns()
#     end
#   end
# end
