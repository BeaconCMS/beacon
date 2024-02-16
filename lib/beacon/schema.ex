defmodule Beacon.Schema do
  @moduledoc false

  alias Ecto.Changeset

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      alias Ecto.Changeset
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts type: :utc_datetime_usec
    end
  end

  def validate_path(%{changes: %{path: "/"}} = changeset), do: changeset

  def validate_path(%{changes: %{path: path}} = changeset) do
    message = "expected path to start with a leading slash '/', got: #{path}"
    Changeset.validate_format(changeset, :path, Beacon.Content.path_format(), message: message)
  end

  def validate_path(changeset), do: changeset
end
