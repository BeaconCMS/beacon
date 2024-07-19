# Custom Repo

Repo is the layer of communication with databases and Beacon requires one to store and fetch data.

By default, the Beacon installer will infer the repo name and add it to your site configuration. But you may use a custom repo that connects
to a different database and/or is fine-tuned for your sites.

Open the file `application.ex`, find the `:repo` option in the site configuration and replace the default repo with your custom repo:

```elixir
children = [
  ...
  {Beacon: sites: [[... repo: YourCustomRepo, ...]]}
]
```