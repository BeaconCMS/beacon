defmodule Beacon.Types.Site do
  @typedoc """
  Site identifier, eg: `:my_site`
  """
  @type t :: atom()

  def valid?(site) when site in ["", nil, true, false], do: false

  def valid?(site) when is_binary(site) do
    Regex.match?(~r/^[a-zA-Z0-9_]+$/, site)
  end

  def valid?(site) when is_atom(site) do
    site |> Atom.to_string() |> valid?()
  end

  def valid?(_site), do: false
end

defmodule Beacon.Types.Atom do
  use Ecto.Type

  def type, do: :atom

  def cast(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}
  def cast(site) when is_atom(site), do: {:ok, site}
  def cast(_), do: :error

  def load(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}

  def dump(site) when is_binary(site), do: {:ok, site}
  def dump(site) when is_atom(site), do: {:ok, Atom.to_string(site)}
  def dump(_), do: :error
end
