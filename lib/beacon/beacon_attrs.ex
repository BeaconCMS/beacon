defmodule Beacon.BeaconAttrs do
  @moduledoc """
  The Beacon attributes for pages.

  This is injected into every page as an assign `@beacon_attrs`,
  and is usually passed to component functions so they can
  resolve paths or fetch the site configuration.
  """

  defstruct site: nil, router: nil

  @type t :: %__MODULE__{
          site: Beacon.Type.Site.t(),
          router: module()
        }
end
