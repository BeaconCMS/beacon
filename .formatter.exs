locals_without_parens = [
  beacon_site: 1,
  beacon_site: 2
]

[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  line_length: 150,
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["{mix,.formatter,dev}.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
