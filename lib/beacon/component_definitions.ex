defmodule Beacon.ComponentDefinitions do
  @moduledoc """
  The ComponentDefinitions context.
  """

  import Ecto.Query, warn: false
  alias Beacon.Content.ComponentDefinition

  alias Beacon.Repo

  @doc """
  Returns the list of component definitions.

  ## Examples

      iex> list_component_definitions()
      [%ComponentDefinitions{}, ...]

  """
  def list_component_definitions do
    Repo.all(ComponentDefinition)
  end

  @doc """
  Gets a single ComponentDefinition.

  Raises `Ecto.NoResultsError` if the ComponentDefinition does not exist.

  ## Examples

      iex> get_component_definition!(123)
      %ComponentDefinition{}

      iex> get_component_definition!(456)
      ** (Ecto.NoResultsError)

  """
  def get_component_definition!(id, preloads \\ []) do
    ComponentDefinition
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end

  @spec create_component_definition(%{optional(:__struct__) => none, optional(atom | binary) => any}) :: any
  @doc """
  Creates a component definition.

  ## Examples

      iex> create_component_definition(%{field: value})
      {:ok, %Component{}}

      iex> create_component_definition(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_component_definition(attrs \\ %{}) do
    %ComponentDefinition{}
    |> ComponentDefinition.changeset(attrs)
    |> Repo.insert()
  end

  def create_component_definition!(attrs \\ %{}) do
    case create_component_definition(attrs) do
      {:ok, component} -> component
      {:error, changeset} -> raise "Failed to create component definition: #{inspect(changeset.errors)}"
    end
  end
end
