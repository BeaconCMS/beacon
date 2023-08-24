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

    %{layout: %{template: layout_template}, template: page_template} =
      site
      |> Beacon.Content.get_error_page(status)
      |> Beacon.Repo.preload(:layout)

    EEx.eval_string(layout_template, assigns: [inner_content: page_template])
  end
end
