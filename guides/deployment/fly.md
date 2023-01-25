# Deploying on Fly.io

Once you have a Beacon site up and running locally, you can have it deployed on https://fly.io by following this guide.

## Fly.io CLI

Firstly instal the fly cli tool as described at https://fly.io/docs/hands-on/install-flyctl. You're gonna use it to deploy your beacon site.

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

Aplications on Fly run on containers, let's generate a Dockerfile and other supporting files, and then make a couple of changes:

Run:

```sh
mix phx.gen.release --docker
```

Edit the generated `Dockerfile` file and make two changes:

1. Add the following code before `RUN mix assets.deploy`:

```
RUN mix tailwind.install
```

2. Add the following code after `USER nobody`:

```
RUN mkdir -p /app/bin/_build
COPY --from=builder --chown=nobody:root /app/_build/tailwind-* ./bin/_build/
```

## Seeds

1. Create the file `rel/overlays/bin/beacon_seeds` with the content:

```shell
#!/bin/sh
cd -P -- "$(dirname -- "$0")"
exec ./my_app eval MyApp.Release.beacon_seeds
```

2. Create the file `rel/overlays/bin/beacon_seeds.bat` with the content:

```shell
call "%~dp0\my_app" eval MyApp.Release.beacon_seeds
```

In both files do:

* Replace `MyApp` with your main application module name
* Replace `my_app` with your application name
* Make them executable by running `chmod +x rel/overlays/bin/beacon_seeds.bat rel/overlays/bin/beacon_seeds` or the equivalent on your system

3. Add this function in the generated `Release` module, usually at `lib/my_app/release.ex`:

```elixir
def beacon_seeds do
  load_app()

  {:ok, _, _} =
    Ecto.Migrator.with_repo(Beacon.Repo, fn _repo ->
      seeds_path = Path.join([:code.priv_dir(@app), "repo", "beacon_seeds.exs"])
      Code.eval_file(seeds_path)
    end)
end
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

## Populate sample data

Before we can access the deployed site let's run seeds to populate some sample data:

1. Connect to your running application:

```sh
fly ssh console
```

2. Open a IEx console:

```sh
app/bin/my_app remote
```

3. Then call your seeds function:

```
MyApp.Release.beacon_seeds
```

Note that you could save some commands and just call `fly ssh console --command "/app/bin/beacon_seeds"` to run seeds, but it may fail and at this momment it's recommended to connected to the instance as showed before.

## Open

Finally run the following command to see your site live:

```sh
fly open my_site/home
```

Change `my_site` to your site name if you have used a custom name when generating your site.

## More commands

You can find all available commands at https://fly.io/docs/flyctl and also more tips on the official [Phoenix Deploying on Fly.io guide](https://github.com/phoenixframework/phoenix/blob/master/guides/deployment/fly.md).
