defmodule BeaconWeb.ErrorHTML do
  @moduledoc false
  use BeaconWeb, :html

  def render(template, assigns) do
    {_, _, %{extra: %{session: %{"beacon_site" => site}}}} = assigns.conn.private.phoenix_live_view

    status =
      template
      |> String.split(".")
      |> hd()
      |> String.to_integer()

    site
    |> Beacon.Content.get_error_page(status)
    |> Map.fetch!(:template)
  end
end
