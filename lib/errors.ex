defmodule Beacon.ConfigError do
  @moduledoc """
  TODO: doc
  """

  defexception message: "error in Beacon.Config"
end

defmodule Beacon.LoaderError do
  @moduledoc """
  TODO: doc
  """

  defexception message: "error in Beacon.Loader", plug_status: 404
end

defmodule Beacon.RuntimeError do
  @moduledoc """
  TODO: doc
  """

  defexception message: "runtime error in Beacon", plug_status: 404
end

defmodule Beacon.AuthorizationError do
  @moduledoc """
  TODO: doc
  """

  defexception message: "error in Beacon.Authorization"
end

defmodule Beacon.ParserError do
  @moduledoc """
  TODO: doc
  """

  defexception message: "error parsing template"
end

defmodule Beacon.SnippetError do
  @moduledoc """
  TODO: doc
  """

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
  @moduledoc """
  TODO: doc
  """

  defexception [:message, plug_status: 404]
end

defmodule BeaconWeb.ServerError do
  @moduledoc """
  TODO: doc
  """

  defexception [:message, plug_status: 500]
end
