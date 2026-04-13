defmodule Beacon.Auth.UnauthorizedError do
  @moduledoc """
  Raised when a user attempts an action they are not authorized to perform.

  Sets `plug_status: 403` so Phoenix/Plug error handlers render a proper
  403 Forbidden response.
  """

  defexception message: "unauthorized", plug_status: 403
end
