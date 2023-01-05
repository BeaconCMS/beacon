defmodule BeaconWeb.Plug do
  alias Plug.Conn
  @behaviour Plug

  @impl Plug
  def init(_) do
    %{}
  end

  @impl Plug
  def call(%Conn{} = conn, _opts) do
    if admin?(conn) do
      Phoenix.Controller.put_root_layout(conn, {BeaconWeb.Layouts, :admin})
    else
      Phoenix.Controller.put_root_layout(conn, {BeaconWeb.Layouts, :runtime})
    end
  end

  # TODO: provide a router macro, eg: beacon_site and beacon_admin
  defp admin?(%{private: %{phoenix_live_view: {lv, _, _}}}) do
    lv |> to_string() |> String.starts_with?("Elixir.BeaconWeb.PageManagement")
  end

  defp admin?(_conn), do: false
end
