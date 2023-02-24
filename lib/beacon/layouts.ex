defmodule Beacon.Layouts do
  @moduledoc """
  The Layouts context.
  """

  import Ecto.Query, warn: false
  alias Beacon.Repo

  alias Beacon.Layouts.Layout

  @doc """
  Returns the list of layouts.

  ## Examples

      iex> list_layouts()
      [%Layout{}, ...]

  """
  def list_layouts do
    Repo.all(Layout)
  end

  def list_layouts_for_site(nil), do: []

  def list_layouts_for_site(site) do
    Repo.all(from l in Layout, where: l.site == ^site)
  end

  @doc """
  Gets a single layout.

  Raises `Ecto.NoResultsError` if the Layout does not exist.

  ## Examples

      iex> get_layout!(123)
      %Layout{}

      iex> get_layout!(456)
      ** (Ecto.NoResultsError)

  """
  def get_layout!(id), do: Repo.get!(Layout, id)

  @doc """
  Creates a layout.

  ## Examples

      iex> create_layout(%{field: value})
      {:ok, %Layout{}}

      iex> create_layout(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_layout(attrs \\ %{}) do
    %Layout{}
    |> Layout.changeset(attrs)
    |> Repo.insert()
  end

  def create_layout!(attrs \\ %{}) do
    case create_layout(attrs) do
      {:ok, layout} -> layout
      {:error, changeset} -> raise "Failed to create layout #{inspect(changeset.errors)} "
    end
  end

  @doc """
  Updates a layout.

  ## Examples

      iex> update_layout(layout, %{field: new_value})
      {:ok, %Layout{}}

      iex> update_layout(layout, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_layout(%Layout{} = layout, attrs) do
    layout
    |> Layout.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a layout.

  ## Examples

      iex> delete_layout(layout)
      {:ok, %Layout{}}

      iex> delete_layout(layout)
      {:error, %Ecto.Changeset{}}

  """
  def delete_layout(%Layout{} = layout) do
    Repo.delete(layout)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking layout changes.

  ## Examples

      iex> change_layout(layout)
      %Ecto.Changeset{data: %Layout{}}

  """
  def change_layout(%Layout{} = layout, attrs \\ %{}) do
    Layout.changeset(layout, attrs)
  end
end
