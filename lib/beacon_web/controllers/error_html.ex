defmodule BeaconWeb.ErrorHTML do
  @moduledoc false
  use BeaconWeb, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates/1 call below
  # and add pages to the error directory:
  #
  #   * lib/beacon_web/controllers/error/404.html.heex
  #   * lib/beacon_web/controllers/error/500.html.heex
  #
  # embed_templates "error/*"

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, assigns) do
    {_, _, %{extra: %{session: %{"beacon_site" => site}}}} = assigns.conn.private.phoenix_live_view

    status =
      template
      |> String.split(".")
      |> hd()
      |> String.to_integer()

    site
    |> Beacon.Content.get_error_page_by_status(status)
    |> Map.fetch!(:template)
  end
end
