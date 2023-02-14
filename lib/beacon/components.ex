defmodule Beacon.Components do
  @moduledoc """
  The Components context.
  """

  import Ecto.Query, warn: false
  alias Beacon.Repo

  alias Beacon.Components.Component

  @doc """
  Returns the list of components for a `site`.

  ## Examples

      iex> list_components()
      [%Component{}, ...]

  """
  def list_components_for_site(site) do
    Repo.all(from c in Component, where: c.site == ^site)
  end

  @doc """
  List all the components' bodies.
  """
  def list_component_bodies do
    Repo.all(from c in Component, select: c.body)
  end

  @doc """
  Gets a single component.

  Raises `Ecto.NoResultsError` if the Component does not exist.

  ## Examples

      iex> get_component!(123)
      %Component{}

      iex> get_component!(456)
      ** (Ecto.NoResultsError)

  """
  def get_component!(id), do: Repo.get!(Component, id)

  @doc """
  Creates a component.

  ## Examples

      iex> create_component(%{field: value})
      {:ok, %Component{}}

      iex> create_component(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_component(attrs \\ %{}) do
    %Component{}
    |> Component.changeset(attrs)
    |> Repo.insert()
  end

  def create_component!(attrs \\ %{}) do
    case create_component(attrs) do
      {:ok, component} -> component
      {:error, changeset} -> raise "Failed to create component: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a component.

  ## Examples

      iex> update_component(component, %{field: new_value})
      {:ok, %Component{}}

      iex> update_component(component, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_component(%Component{} = component, attrs) do
    component
    |> Component.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a component.

  ## Examples

      iex> delete_component(component)
      {:ok, %Component{}}

      iex> delete_component(component)
      {:error, %Ecto.Changeset{}}

  """
  def delete_component(%Component{} = component) do
    Repo.delete(component)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking component changes.

  ## Examples

      iex> change_component(component)
      %Ecto.Changeset{data: %Component{}}

  """
  def change_component(%Component{} = component, attrs \\ %{}) do
    Component.changeset(component, attrs)
  end
end
