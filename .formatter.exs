locals_without_parens = [
  beacon_site: 1,
  beacon_site: 2,
  beacon_api: 1
]

[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  line_length: 150,
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
