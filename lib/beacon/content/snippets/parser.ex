defmodule Beacon.Content.Snippets.Parser do
  @moduledoc false

  use Solid.Parser.Base, custom_tags: [Beacon.Content.Snippets.TagHelper]
end
