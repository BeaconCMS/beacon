defmodule BeaconWeb.API.Plug do
  @moduledoc false

  use Plug.Builder

  plug Accent.Plug.Request, default_case: Accent.Case.Snake
  plug Accent.Plug.Response, default_case: Accent.Case.Camel, json_codec: Jason
end
