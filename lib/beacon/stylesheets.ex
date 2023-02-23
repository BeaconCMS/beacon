defmodule Beacon.Stylesheets do
  @moduledoc """
  The Stylesheets context.
  """

  import Ecto.Query, warn: false
  alias Beacon.Repo

  alias Beacon.Stylesheets.Stylesheet

  @doc """
  Returns the list of stylesheets for `site`.

  ## Examples

      iex> list_stylesheets()
      [%Stylesheet{}, ...]

  """
  def list_stylesheets_for_site(site) do
    Repo.all(
      from s in Stylesheet,
        where: s.site == ^site
    )
  end

  @doc """
  Gets a single stylesheet.

  Raises `Ecto.NoResultsError` if the Stylesheet does not exist.

  ## Examples

      iex> get_stylesheet!(123)
      %Stylesheet{}

      iex> get_stylesheet!(456)
      ** (Ecto.NoResultsError)

  """
  def get_stylesheet!(id), do: Repo.get!(Stylesheet, id)

  @doc """
  Creates a stylesheet.

  ## Examples

      iex> create_stylesheet(%{field: value})
      {:ok, %Stylesheet{}}

      iex> create_stylesheet(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stylesheet(attrs \\ %{}) do
    %Stylesheet{}
    |> Stylesheet.changeset(attrs)
    |> Repo.insert()
  end

  def create_stylesheet!(attrs \\ %{}) do
    case create_stylesheet(attrs) do
      {:ok, stylesheet} -> stylesheet
      {:error, changeset} -> raise "Failed to create stylesheet: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Updates a stylesheet.

  ## Examples

      iex> update_stylesheet(stylesheet, %{field: new_value})
      {:ok, %Stylesheet{}}

      iex> update_stylesheet(stylesheet, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_stylesheet(%Stylesheet{} = stylesheet, attrs) do
    stylesheet
    |> Stylesheet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a stylesheet.

  ## Examples

      iex> delete_stylesheet(stylesheet)
      {:ok, %Stylesheet{}}

      iex> delete_stylesheet(stylesheet)
      {:error, %Ecto.Changeset{}}

  """
  def delete_stylesheet(%Stylesheet{} = stylesheet) do
    Repo.delete(stylesheet)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stylesheet changes.

  ## Examples

      iex> change_stylesheet(stylesheet)
      %Ecto.Changeset{data: %Stylesheet{}}

  """
  def change_stylesheet(%Stylesheet{} = stylesheet, attrs \\ %{}) do
    Stylesheet.changeset(stylesheet, attrs)
  end
end
