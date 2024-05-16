defmodule Beacon.Types.JsonArrayMap do
  @moduledoc """
  Convert between json and map enforcing the data shape as array of objects/maps.
  """

  use Ecto.Type

  @typedoc """
  List of maps
  """
  @type t :: [map()]

  def type, do: {:array, :map}

  def cast(term) when is_map(term), do: {:ok, [term]}

  def cast(term) when is_list(term) do
    case validate(term) do
      {true, list} ->
        {:ok, list}

      {false, list} ->
        {:error, message: "expected a list of map or a map, got: #{inspect(list)}"}
    end
  end

  def cast(term) when is_binary(term) do
    case decode(term) do
      {:ok, term} -> cast(term)
      {:error, message} -> {:error, message: message}
    end
  end

  def cast(term) do
    {:error, message: "expected a list of map or a map, got: #{inspect(term)}"}
  end

  def dump(term) when is_map(term), do: {:ok, [term]}

  def dump(term) when is_list(term) do
    case validate(term) do
      {true, list} ->
        {:ok, list}

      {false, _list} ->
        :error
    end
  end

  def dump(term) when is_binary(term) do
    case decode(term) do
      {:ok, term} -> dump(term)
      {:error, _message} -> :error
    end
  end

  def dump(_site), do: :error

  def load(term) when is_map(term), do: {:ok, [term]}

  def load(term) when is_list(term), do: {:ok, term}

  def load(term) when is_binary(term) do
    case decode(term) do
      {:ok, term} -> load(term)
      {:error, _message} -> :error
    end
  end

  def load(_term), do: :error

  defp validate(term) when is_list(term) do
    {valid, list} =
      Enum.reduce_while(term, {true, []}, fn
        t, {_valid, list} when is_map(t) ->
          {:cont, {true, [t | list]}}

        t, {_, list} ->
          {:halt, {false, [t | list]}}
      end)

    {valid, Enum.reverse(list)}
  end

  defp validate(term), do: {false, term}

  defp decode(term) when is_binary(term) do
    case Jason.decode(term) do
      {:ok, term} ->
        {:ok, term}

      {:error, error} ->
        message = Exception.message(error)
        {:error, "expected a list of map or a map, got error: #{message}"}
    end
  end
end
