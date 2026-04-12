defmodule Beacon.Web.API.AuthPlug do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        if valid_api_key?(token) do
          conn
        else
          conn
          |> put_status(401)
          |> Phoenix.Controller.json(%{error: "invalid api key"})
          |> halt()
        end

      _ ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{error: "missing authorization header"})
        |> halt()
    end
  end

  defp valid_api_key?(token) do
    # Check against configured API keys for any site
    # In production, this should validate against stored keys
    case Application.get_env(:beacon, :api_keys) do
      nil -> false
      keys when is_list(keys) -> token in keys
      key when is_binary(key) -> token == key
    end
  end
end
