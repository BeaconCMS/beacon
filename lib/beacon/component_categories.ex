defmodule Beacon.ComponentCategories do
  @moduledoc """
  The ComponentCategories context.
  """

  import Ecto.Query, warn: false
  alias Beacon.ComponentCategories.ComponentCategory

  alias Beacon.Repo

  @doc """
  Returns the list of component categories.

  ## Examples

      iex> list_component_categories()
      [%ComponentCategories{}, ...]

  """
  def list_component_categories() do
    ComponentCategory |> Repo.all()
  end
end
