defmodule Beacon.BeaconAttrs do
  @moduledoc """
  The public Beacon's attributes for each page.

  It's injected into the Live View process and also as an assign `@beacon_attrs`.
  """

  defstruct site: nil, prefix: nil

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          prefix: String.t()
        }
end
