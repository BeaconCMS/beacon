defmodule Beacon.Types.Binary do
  @moduledoc """
  Store Elixir terms into the database as binary.

  Used to store and load layout and page snapshots.
  """

  use Ecto.Type

  def type, do: :binary

  def cast(term) when is_binary(term), do: {:ok, term}
  def cast(term), do: {:ok, :erlang.term_to_binary(term)}

  def dump(term) when is_binary(term), do: {:ok, term}
  def dump(term), do: {:ok, :erlang.term_to_binary(term)}

  def load(binary) when is_binary(binary), do: {:ok, :erlang.binary_to_term(binary)}
  def load(_binary), do: :error
end
