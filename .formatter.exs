locals_without_parens = [
  beacon_site: 1,
  beacon_site: 2,
  beacon_sitemap_index: 1
]

[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  line_length: 150,
  plugins: [Phoenix.LiveView.HTMLFormatter],
  migrate_eex_to_curly_interpolation: false,
  inputs: ["{mix,.formatter,dev}.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
