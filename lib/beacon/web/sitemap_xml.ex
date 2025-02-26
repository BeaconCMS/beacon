defmodule Beacon.Web.SitemapXML do
  @moduledoc false
  import Phoenix.Template, only: [embed_templates: 1]
  embed_templates "sitemap/*.xml"
end
