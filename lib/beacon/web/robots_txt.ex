defmodule Beacon.Web.RobotsTxt do
  import Phoenix.Template, only: [embed_templates: 1]
  embed_templates "robots/*.txt"
end
