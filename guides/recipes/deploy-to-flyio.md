# Deploying on Fly.io

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

Applications on Fly run in containers. Let's generate a Dockerfile and make a couple of changes to that file:

Run:

```sh
mix phx.gen.release --docker
```

Edit the generated `Dockerfile` and make two changes:

1. Add the following code before `RUN mix assets.deploy`:

```
RUN mix tailwind.install --no-assets
```

2. Add the following code before `USER nobody`:

```dockerfile
# Copy the tailwind-cli binary used to compile stylesheets for pages
RUN mkdir -p ./bin/_build
COPY --from=builder --chown=nobody:root /app/_build/tailwind-* ./bin/_build/

# Copy heroicons svg files to used on the icon component
RUN mkdir -p ./vendor
COPY --from=builder --chown=nobody:root /app/deps/heroicons ./vendor/heroicons
```

## Launch

With your account in place and all files updated, it's time to launch your application. Run:

```sh
fly launch
```

When asked if you would like to set up a PostgreSQL database, answer YES and choose the most appropriate configuration for your site.

When asked if you would like to deploy, answer YES or run `fly deploy` afterwards when you're ready to deploy.

## Deploy

Beacon is designed to minimize deployments as much as possible, but eventually you can trigger new deployments by running:

```sh
fly deploy
```

## Open

Finally, if you followed the guides to setup your site, run the following command to see it live:

```sh
fly open /
```

If you have created a custom page, simply replace `/` in the above command to match its path

## More commands

You can find all available commands in the [Fly.io docs](https://fly.io/docs/flyctl) and also find more tips on the official [Phoenix Deploying on Fly.io guide](https://fly.io/docs/elixir/getting-started/).
