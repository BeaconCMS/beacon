defmodule Beacon.Template.LoadMetadata do
  @moduledoc """
  Metadata passed to page loading lifecycle.
  """

  defstruct [:site, :path]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t()
        }
end
