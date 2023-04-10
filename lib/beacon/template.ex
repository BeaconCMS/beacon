defmodule Beacon.Template.LoadMetadata do
  @moduledoc """
  Metadata passed to page loading lifecycle.

  See `t:Beacon.Config.template_formats/0`
  """

  defstruct [:site, :path]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t()
        }
end

defmodule Beacon.Template.RenderMetadata do
  @moduledoc """
  Metadata passed to page rendering lifecycle.

  See `t:Beacon.Config.template_formats/0`
  """

  defstruct [:site, :path, :assigns, :env]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t(),
          assigns: Phoenix.LiveView.Socket.assigns(),
          env: Macro.Env.t()
        }
end

defmodule Beacon.Template do
  @typedoc """
  Compiled template.
  """
  @type ast :: Macro.t()

  @type t :: String.t() | ast()

  defguard is_ast(template) when not is_binary(template)
end
