defmodule Beacon.Template.LoadMetadata do
  @moduledoc """
  Load Stage
  TODO
  """

  defstruct [:site, :path]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t()
        }
end

defmodule Beacon.Template.RenderMetadata do
  @moduledoc """
  Render Stage
  TODO
  """

  defstruct [:site, :path, :assigns, :env]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t(),
          assigns: Phoenix.LiveView.Socket.assigns() | nil,
          # TODO: type
          env: any()
        }
end

defmodule Beacon.Template do
  @typedoc """
  Compiled template TODO
  """
  @type ast :: Macro.t()

  @type t :: String.t() | ast()

  defguard is_ast(template) when not is_binary(template)
end
