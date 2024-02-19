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

  def validate_path(%Changeset{} = changeset) do
    Changeset.validate_change(changeset, :path, fn :path, path ->
      case validate_path(path) do
        {:ok, _} -> []
        {:error, error} -> [path: error]
      end
    end)
  end

  def validate_path(<<"/", _rest::binary>> = path) do
    not_allowed = :binary.compile_pattern([" ", "?", "="])

    cond do
      String.contains?(path, not_allowed) ->
        {:error, "invalid path, no space or query allowed, got: #{path}"}

      :default ->
        {:ok, Plug.Router.Utils.build_path_match(path)}
    end
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  def validate_path(path), do: {:error, "invalid path, it must start with a leading slash '/', got: #{path}"}
end
