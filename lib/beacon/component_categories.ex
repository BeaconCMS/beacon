defmodule Beacon.ComponentCategories do
  @moduledoc """
  The ComponentCategories context.
  """

  import Ecto.Query, warn: false
  alias Beacon.Content.ComponentCategory

  alias Beacon.Repo

  @doc """
  Returns the list of component categories.

  ## Examples

      iex> list_component_categories()
      [%ComponentCategories{}, ...]

  """
  def list_component_categories do
    ComponentCategory |> Repo.all()
  end

  @spec create_component_category(%{optional(:__struct__) => none, optional(atom | binary) => any}) :: any
  @doc """
  Creates a component category.

  ## Examples

      iex> create_component_category(%{field: value})
      {:ok, %Component{}}

      iex> create_component_category(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_component_category(attrs \\ %{}) do
    %ComponentCategory{}
    |> ComponentCategory.changeset(attrs)
    |> Repo.insert()
  end

  def create_component_category!(attrs \\ %{}) do
    case create_component_category(attrs) do
      {:ok, component} -> component
      {:error, changeset} -> raise "Failed to create component category: #{inspect(changeset.errors)}"
    end
  end
end
