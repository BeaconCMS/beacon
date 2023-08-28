defmodule Beacon.Utils do
  @moduledoc false

  # https://elixirforum.com/t/dynamically-generate-typespecs-from-module-attribute-list/7078/5
  def list_to_typespec(list) when is_list(list) do
    Enum.reduce(list, &{:|, [], [&1, &2]})
  end
end
