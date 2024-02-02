defmodule Beacon.Types.Atom do
  @moduledoc """
  Convert between atom and string.
  """

  use Ecto.Type

  def type, do: :atom

  def cast(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}
  def cast(site) when is_atom(site), do: {:ok, site}
  def cast(site), do: {:error, message: "invalid site #{inspect(site)}"}

  def dump(site) when is_binary(site), do: {:ok, site}
  def dump(site) when is_atom(site), do: {:ok, Atom.to_string(site)}
  def dump(_site), do: :error

  def equal?(site1, site2), do: site1 === site2

  def load(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}
  def load(_site), do: :error

  def safe_to_atom(value) when is_atom(value), do: value
  def safe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
end
