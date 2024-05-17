# Deploying on Fly.io

Once you have a [Beacon site up and running](https://github.com/BeaconCMS/beacon/blob/main/guides/your-first-site.md) locally, you can have it deployed on [Fly.io](https://fly.io) by following this guide.

## Fly.io CLI

Firstly instal the fly cli tool as described at [Install flyctl](https://fly.io/docs/hands-on/install-flyctl), you'll need it to deploy your site.

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

Aplications on Fly run on containers, let's generate a Dockerfile and then make a couple of changes on that file:

Run:

```sh
mix phx.gen.release --docker
```

Edit the generated `Dockerfile` file and make two changes:

1. Add the following code before `RUN mix assets.deploy`:

```
RUN mix tailwind.install --no-assets
```

2. Add the following code after `USER nobody`:

```
RUN mkdir -p /app/bin/_build
COPY --from=builder --chown=nobody:root /app/_build/tailwind-* ./bin/_build/
```

## Database connection

Edit `config/runtime.exs` and add the following config after `config :my_app, MyApp.Repo, ...`:

```elixir
config :beacon, Beacon.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6
```

## Launch

With your account in place and all files updated, it's time to launch your application. Run and follow the instructions:

```sh
fly launch
```

When asked if you would like to set up a PostgreSQL database, answer YES and choose the most appropriate configuration for your site.

When asked if you would like to deploy, answer YES or run `fly deploy` afterwards when you're ready to deploy.

## Deploy

Beacon is designed to minimize deployments as much as possible but eventually you can trigger new deployments by running:

```sh
fly deploy
```

## Open

Finally, run the following command to see your site live:

```sh
fly open /
```

Change the path if you have created a custom page and not followed the guides.

## More commands

You can find all available commands in the [Fly.io docs](https://fly.io/docs/flyctl) and also find more tips on the official [Phoenix Deploying on Fly.io guide](https://fly.io/docs/elixir/getting-started/).
