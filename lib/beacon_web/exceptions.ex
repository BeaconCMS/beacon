defmodule Beacon.LoaderError do
  # Using `plug_status` for rendering this exception as 404 in production.
  # More info: https://hexdocs.pm/phoenix/custom_error_pages.html#custom-exceptions
  defexception message: "Error in Beacon.Loader", plug_status: 404
end

defmodule Beacon.AuthorizationError do
  defexception message: "Error in Beacon.Authorization"
end

defmodule Beacon.ParserError do
  defexception message: "Error parsing template"
end

defmodule Beacon.SnippetError do
  defexception [:message]

  @type t() :: %__MODULE__{
          message: String.t()
        }

  @impl true
  def exception(%Solid.TemplateError{} = error) do
    message = Exception.message(error)
    %__MODULE__{message: message}
  end

  def exception(error) when is_binary(error), do: %__MODULE__{message: error}
  def exception(_error), do: %__MODULE__{message: "failed to process snippet"}
end

defmodule BeaconWeb.NotFoundError do
  defexception [:message, plug_status: 404]
end
