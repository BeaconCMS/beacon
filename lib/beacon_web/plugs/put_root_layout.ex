defmodule BeaconWeb.Plug do
  alias Plug.Conn
  @behaviour Plug

  @impl Plug
  def init(_) do
    %{}
  end

  @impl Plug
  def call(%Conn{} = conn, _) do
    Phoenix.Controller.put_root_layout(conn, {BeaconWeb.LayoutView, "root.html"})
  end
end
