# Deploy to Fly.io

Once you have a [Beacon site up and running](../introduction/your-first-site.md) locally, you can deploy it on [Fly.io](https://fly.io) by following this guide.

## Fly.io CLI

First, install the fly cli tool, as described at [Install flyctl](https://fly.io/docs/hands-on/install-flyctl). You'll need it to deploy your site.

## Sign in or sign up

Don't have an account yet? Sign up by running:

```sh
fly auth signup
```

Or sign in to your existing account:

```sh
fly auth login
```

## Dockerfile

Fly applications run in containers. Let's generate a Dockerfile and make a couple of changes:

Run:

```sh
mix phx.gen.release --docker
```

Edit the generated `Dockerfile` and make some changes:

1. Install `npm` by adding it to the `apt-get install` list

It should look like this:

```dockerfile
RUN apt-get update -y && apt-get install -y build-essential git npm \
```

2. Add the following code before `RUN mix assets.deploy`:

```dockerfile
RUN npm install --prefix assets
```

## Copy files into the release

Open the file `mix.exs` and locate the `project/0` function. Add a new `:releases` config that contains a custom step to copy Beacon files:

```elixir
releases: [
  my_app: [
    steps: [:assemble, &copy_beacon_files/1]
  ]
]
```

Replace `my_app` with your actual app name. The whole function will look similar to this:

```elixir
def project do
  [
    app: :my_app,
    version: "0.1.0",
    elixir: "~> 1.14",
    elixirc_paths: elixirc_paths(Mix.env()),
    start_permanent: Mix.env() == :prod,
    consolidate_protocols: Mix.env() != :dev,
    aliases: aliases(),
    deps: deps(),
    releases: [
      my_app: [
        steps: [:assemble, &copy_beacon_files/1]
      ]
    ]
  ]
end
```

Now create a new function `copy_beacon_files/1` at any place in the `mix.exs` file:

```elixir
defp copy_beacon_files(%{path: path} = release) do
  case Path.wildcard("_build/tailwind-*") do
    [] ->
      raise """
      tailwind-cli not found

      Execute the following command to install it before proceeding:

          mix tailwind.install

      """

    tailwind_bin_path ->
      build_path = Path.join([path, "bin", "_build"])
      File.mkdir_p!(build_path)

      for file <- tailwind_bin_path do
        File.cp!(file, Path.join(build_path, Path.basename(file)))
      end
  end

  File.cp!(Path.join(["assets", "css", "app.css"]), Path.join(path, "app.css"))

  release
end
````

Essentially this function will copy the `tailwind-cli` binary and the `app.css` files into the release.
The `tailwind-cli` binary is required but `app.css` is only used if you actually [reuse it on your sites](reuse-app-css.md).

See  https://hexdocs.pm/mix/Mix.Tasks.Release.html for more info about releases configuration.

## Launch

With your account in place and all files updated, it's time to launch your application. Run:

```sh
fly launch
```

When asked if you would like to set up a PostgreSQL database, answer YES and choose the most appropriate configuration for your site.

When asked if you would like to deploy, answer YES or run `fly deploy` afterward when you're ready to deploy.

## Deploy

Beacon is designed to minimize deployments as much as possible, but eventually, you can trigger new deployments by running:

```sh
fly deploy
```

## Open

Finally, if you followed the guides to set up your site, run the following command to see it live:

```sh
fly open /
```

If you have created a custom page, simply replace `/` in the above command to match its prefix.

## More commands

You can find all available commands in the [Fly.io docs](https://fly.io/docs/flyctl) and also find more tips on the official [Phoenix Deploying on Fly.io guide](https://fly.io/docs/elixir/getting-started/).

## Troubleshooting

The default config file `fly.toml` created by `fly launch` defines `min_machines_running = 0` so Fly will auto-stop machines
that receive no traffic for a period of time. You might want to change this value to `1` otherwise it will look like your app
is not working, when in fact it's just Fly proxy doing its job.
