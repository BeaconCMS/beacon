defmodule Beacon.Utils do
  @moduledoc false

  # https://elixirforum.com/t/dynamically-generate-typespecs-from-module-attribute-list/7078/5
  def list_to_typespec(list) when is_list(list) do
    Enum.reduce(list, &{:|, [], [&1, &2]})
  end

  @doc """
  For debugging - convert a quoted expression to string

  Useful to log module body or write a file.

  ## Examples

      # print module body
      quoted |> Beacon.Utils.quoted_to_string() |> IO.puts()

      # write to a persisted file
      File.write!("module.ex", Beacon.Utils.quoted_to_binary(quoted))

  """
  def quoted_to_binary(ast) do
    ast
    |> Code.quoted_to_algebra()
    |> Inspect.Algebra.format(:infinity)
    |> IO.iodata_to_binary()
  end
end
