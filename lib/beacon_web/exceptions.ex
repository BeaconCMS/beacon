defmodule Beacon.LoaderError do
  defexception message: "error in Beacon.Loader", plug_status: 404
end

defmodule Beacon.RuntimeError do
  defexception message: "runtime error in Beacon", plug_status: 404
end

defmodule Beacon.AuthorizationError do
  defexception message: "error in Beacon.Authorization"
end

defmodule Beacon.ParserError do
  defexception message: "error parsing template"
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
