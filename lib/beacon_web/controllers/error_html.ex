defmodule BeaconWeb.ErrorHTML do
  @moduledoc false
  use BeaconWeb, :html

  alias Beacon.Loader

  def render(template, assigns) do
    {_, _, %{extra: %{session: %{"beacon_site" => site}}}} = assigns.conn.private.phoenix_live_view
    error_module = Loader.error_module_for_site(site)

    status =
      template
      |> String.split(".")
      |> hd()
      |> String.to_integer()

    error_module.render(status)
  end
end
