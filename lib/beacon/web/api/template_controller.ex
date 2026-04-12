defmodule Beacon.Web.API.TemplateController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]

  require Logger

  @doc """
  Called after a page is published to push compiled IR to connected clients.

  POST /api/templates/:site/push
  Body: %{path: "/blog/hello", ir: binary, assets: map, event_handlers: [...]}

  Event handler action documents are HMAC-signed so clients can verify integrity.
  """
  def push(conn, %{"site" => site_str, "path" => path, "ir" => ir} = params) do
    site = String.to_existing_atom(site_str)
    assets = Map.get(params, "assets", %{})
    event_handlers = Map.get(params, "event_handlers", [])

    # Sign any action-format event handlers
    signed_handlers = sign_action_handlers(event_handlers)

    Phoenix.PubSub.broadcast(
      Beacon.PubSub,
      "beacon:#{site}:template_push",
      {:template_pushed, %{
        site: site,
        path: path,
        ir: ir,
        assets: assets,
        event_handlers: signed_handlers
      }}
    )

    Logger.info("[Beacon.API] Template pushed for #{site}#{path}")
    json(conn, %{status: "ok"})
  rescue
    ArgumentError ->
      conn |> put_status(404) |> json(%{error: "site not found"})
  end

  defp sign_action_handlers(handlers) do
    secret = Application.get_env(:beacon, :action_signing_secret)

    Enum.map(handlers, fn
      %{"format" => "actions", "actions" => actions} = handler when is_binary(secret) ->
        signature = Beacon.Actions.Security.sign(actions, secret)
        Map.put(handler, "signature", signature)

      handler ->
        handler
    end)
  end
end
