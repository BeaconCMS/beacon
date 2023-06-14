defmodule Beacon.Snippets.Parser do
  @moduledoc false

  use Solid.Parser.Base, custom_tags: [Beacon.Snippets.Tags.Helper]
end
