defmodule Beacon.Web.RobotsTxt do
  @moduledoc false
  import Phoenix.Template, only: [embed_templates: 1]
  embed_templates "robots/*.txt"
end
