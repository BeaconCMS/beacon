defmodule Beacon.ComponentInstances do
  @moduledoc """
  The ComponentInstance context.
  """

  import Ecto.Query, warn: false
  alias Beacon.Content.ComponentInstance

  alias Beacon.Repo

  @doc """
  Returns the list of component instances.

  ## Examples

      iex> list_component_instances()
      [%ComponentInstance{}, ...]

  """
  def list_component_instances do
    Repo.all(ComponentInstance)
  end

  @doc """
  Gets a single ComponentInstance.

  Raises `Ecto.NoResultsError` if the ComponentInstance does not exist.

  ## Examples

      iex> get_component_instance!(123)
      %ComponentInstance{}

      iex> get_component_instance!(456)
      ** (Ecto.NoResultsError)

  """
  def get_component_instance!(id, preloads \\ []) do
    ComponentInstance
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end

  @spec create_component_instance(%{optional(:__struct__) => none, optional(atom | binary) => any}) :: any
  @doc """
  Creates a component instance.

  ## Examples

      iex> create_component_instance(%{field: value})
      {:ok, %Component{}}

      iex> create_component_instance(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_component_instance(attrs \\ %{}) do
    %ComponentInstance{}
    |> ComponentInstance.changeset(attrs)
    |> Repo.insert()
  end

  def create_component_instance!(attrs \\ %{}) do
    case create_component_instance(attrs) do
      {:ok, component} -> component
      {:error, changeset} -> raise "Failed to create component instance: #{inspect(changeset.errors)}"
    end
  end

  def update_component_instance_data(component_instance, data) do
    component_instance
    |> ComponentInstance.changeset(%{data: data})
    |> Repo.update()
  end
end
