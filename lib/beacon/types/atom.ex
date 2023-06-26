defmodule Beacon.Types.Atom do
  @moduledoc false

  use Ecto.Type

  def type, do: :atom

  def cast(:any, site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}
  def cast(:any, site) when is_atom(site), do: {:ok, site}
  def cast(:any, _), do: :error

  def cast(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}
  def cast(site) when is_atom(site), do: {:ok, site}
  def cast(_), do: :error

  def load(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}

  def dump(site) when is_binary(site), do: {:ok, site}
  def dump(site) when is_atom(site), do: {:ok, Atom.to_string(site)}
  def dump(_), do: :error
end
