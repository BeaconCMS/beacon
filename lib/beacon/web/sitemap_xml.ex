defmodule Beacon.Web.SitemapXML do
  import Phoenix.Template, only: [embed_templates: 1]
  embed_templates "sitemap/*.xml"
end
