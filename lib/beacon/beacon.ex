defmodule Beacon do
  @moduledoc """
  BeaconCMS
  """

  @tailwind_version "3.2.4"

  @doc false
  def tailwind_version, do: @tailwind_version

  @doc false
  def persist_term(key, value) do
    term = get_term(key)
    if term, do: term, else: :persistent_term.put(key, value)
  rescue
    ArgumentError ->
      :persistent_term.put(key, value)
  end

  @doc false
  def get_term(key) do
    :persistent_term.get(key)
  end
end
