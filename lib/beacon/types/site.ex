defmodule Beacon.Types.Site do
  @moduledoc """
  Sites are identified as atoms and stored as string in the database.
  """

  use Ecto.Type

  @typedoc """
  Atom to identify a site, eg: `:my_site`
  """
  @type t :: atom()

  @doc """
  Returns `true` if `site` is valid, otherwise returns `false`.

  A site is valid if it's a atom with no special characters, except `_`.

  ## Examples

      iex> valid?(:my_site)
      true

      iex> valid?(:"my-site!")
      false

  """
  def valid?(site) when site in ["", nil, true, false], do: false

  def valid?(site) when is_binary(site) do
    Regex.match?(~r/^[a-zA-Z0-9_]+$/, site)
  end

  def valid?(site) when is_atom(site) do
    site = Atom.to_string(site)
    Regex.match?(~r/^[a-zA-Z0-9_]+$/, site)
  end

  def valid?(_site), do: false

  def valid_name?(site) when is_atom(site) do
    valid_name?(Atom.to_string(site))
  end

  def valid_name?(site) when is_binary(site) do
    not String.starts_with?(site, "beacon_")
  end

  def valid_path?(path) when is_atom(path) do
    path |> Atom.to_string() |> valid_path?()
  end

  def valid_path?(path) when is_binary(path) do
    String.starts_with?(path, "/")
  end

  @doc false
  def type, do: :atom

  @doc false
  def cast(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}
  def cast(site) when is_atom(site), do: {:ok, site}
  def cast(site), do: {:error, message: "invalid site #{inspect(site)}"}

  @doc false
  def dump(site) when is_binary(site), do: {:ok, site}
  def dump(site) when is_atom(site), do: {:ok, Atom.to_string(site)}
  def dump(_site), do: :error

  @doc false
  def load(site) when is_binary(site), do: {:ok, String.to_existing_atom(site)}
  def load(_site), do: :error
end
