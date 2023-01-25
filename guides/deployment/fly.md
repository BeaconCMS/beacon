# Deploying on Fly.io

Once you have a Beacon site up and running locally you can have it deployed on https://fly.io by following this guide.

While Fly provides its own guide to [deploy Elixir apps](https://fly.io/docs/elixir/getting-started/), this will guide you trough all necessary steps but you may check out their docs as well.

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

WIP

1. Create the file `rel/overlays/bin/seeds` with the content:

```shell
#!/bin/sh
cd -P -- "$(dirname -- "$0")"
exec ./beacon_demo eval BeaconDemo.Release.beacon_seeds
```

Make it executable.

2. Create the file `rel/overlays/bin/seeds.bat` with the content:

```shell
call "%~dp0\beacon_demo" eval BeaconDemo.Release.beacon_seeds
```

Make it executable.

3. Add the function in the generated `Release` module:

```elixir
def beacon_seeds do
  load_app()
  Application.load(:beacon)

  {:ok, _, _} =
    Ecto.Migrator.with_repo(Beacon.Repo, fn _repo ->
      seeds_path = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])
      Code.eval_file(seeds_path)
    end)
end
```

## Launch

With your account in place and all files updated, it's time to launch your application. Run and follow the instructions:

```sh
fly launch
```

When asked if you would like to set up a PostgreSQL database, answer YES and choose the most appropriate configuration for your site.

When asked if you want to deploy, answer YES or run `fly deploy` when you're ready to deploy.

## Deploy

Beacon is designed to minimize deployments as much as possible but eventually you can run to trigger new deployments:

```sh
fly deploy
```

## Open

Finally run the following command to see your site live:

```sh
fly open
```

## More commands

You can find all available commands at https://fly.io/docs/flyctl and also more tips on the official Phoenix guide at https://github.com/phoenixframework/phoenix/blob/master/guides/deployment/fly.md
