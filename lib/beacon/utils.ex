defmodule Beacon.Utils do
  @moduledoc false

  # https://elixirforum.com/t/dynamically-generate-typespecs-from-module-attribute-list/7078/5
  def list_to_typespec(list) when is_list(list) do
    Enum.reduce(list, &{:|, [], [&1, &2]})
  end

  # For debugging - will print module content to the terminal
  def ast_to_binary(ast) do
    ast
    |> Code.quoted_to_algebra()
    |> Inspect.Algebra.format(:infinity)
    |> IO.iodata_to_binary()
  end
end
