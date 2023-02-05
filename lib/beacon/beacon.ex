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

  def default_site_meta_tags() do
    [
      %{"charset" => "utf-8"},
      %{"http-equiv" => "X-UA-Compatible", "content" => "IE=edge"},
      %{"name" => "viewport", "content" => "width=device-width, initial-scale=1"},
      %{"name" => "csrf-token", "content" => Phoenix.Controller.get_csrf_token()}
    ] 
    |> Enum.map(fn tags -> Map.to_list(tags) end) 
    |> order
  end

  defp order(tags) do
    Enum.map(tags, 
      fn tag ->
        Enum.sort_by(tag, 
          fn kv = {"charset", _} -> 
            kv 
          kv = {"http-equiv", _} ->
            kv 
          kv = {"name", _} -> 
            kv
          kv = {"content", _} -> 
            kv
          _ ->
          end, &==/2)
    end)
  end
end
