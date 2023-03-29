defmodule BeaconWeb.NotFoundError do
  defexception [:message, plug_status: 404]
end

defmodule Beacon.LoaderError do
  # Using `plug_status` for rendering this exception as 404 in production.
  # More info: https://hexdocs.pm/phoenix/custom_error_pages.html#custom-exceptions
  defexception message: "Error in Beacon.Loader", plug_status: 404
end

defmodule Beacon.DataSourceError do
  defexception message: "Error in Beacon.DataSource"
end

defmodule Beacon.AuthorizationError do
  defexception message: "Error in Beacon.Authorization"
end
