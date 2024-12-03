defmodule Beacon.Template.RenderMetadata do
  @moduledoc """
  Metadata passed to page rendering lifecycle.
  """

  defstruct [:site, :path, :page_module, :assigns, :env]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t(),
          page_module: module(),
          assigns: Phoenix.LiveView.Socket.assigns(),
          env: Macro.Env.t()
        }
end
