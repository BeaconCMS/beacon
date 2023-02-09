defmodule Beacon.Type.Site do
  @moduledoc false

  use Ecto.Type

  @type t :: atom()

  def valid?(site) when site in ["", nil, true, false], do: false

  def valid?(site) when is_binary(site) do
    Regex.match?(~r/^[a-zA-Z0-9_]+$/, site)
  end

  def valid?(site) when is_atom(site) do
    site |> Atom.to_string() |> valid?()
  end

  def valid?(_site), do: false

  def type, do: :atom

  def cast(site) when is_binary(site) do
    {:ok, String.to_existing_atom(site)}
  end

  def cast(site) when is_atom(site) do
    {:ok, site}
  end

  def cast(_), do: :error

  def load(site) when is_binary(site) do
    {:ok, String.to_existing_atom(site)}
  end

  def dump(site) when is_binary(site) do
    {:ok, site}
  end

  def dump(site) when is_atom(site) do
    {:ok, Atom.to_string(site)}
  end

  def dump(_), do: :error
end
