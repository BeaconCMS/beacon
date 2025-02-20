# Troubleshooting

Solutions to common problems.

## Server crashes due to missing tailwind or tailwind fails to generate stylesheets

**Possible causes:**
- Tailwind library not installed
- Outdated tailwind version
- Missing tailwind binary
- Invalid tailwind configuration

Any recent Phoenix application should come with the [tailwind](https://hex.pm/packages/tailwind) library already installed and updated
so let's check if everything is in place. Execute:

```sh
mix run -e "IO.inspect Tailwind.bin_version()"
```

It should display `{:ok, "3.4.3"}` (or any other version).

If it fails or the version is lower than **3.3.0** then follow the [tailwind install guide](https://github.com/phoenixframework/tailwind?tab=readme-ov-file#installation)
to get it installed or updated. It's important to install a recent Tailwind version higher than 3.3.0

## Site not booting because it's not reachable

Depending on the [deployment topology](https://hexdocs.pm/beacon/deployment-topologies.html) and your router configuration,
a site prefix can never match and it will never receive requests.

That's is not necessarily an error if you have multiple sites in the same project and is using the router scope `:host` option
to selectively start sites based on the current host.

The most common causes for this error are: 

1. Mismatch between the Endpoint host/ip config and the route scope `:host` 

Suppose your Endpoint configuration is:

```elixir
config :my_app,
       MyAppWeb.BlogEndpoint,
       http: [ip: {127, 0, 0, 1}, port: 4586],
       ...
```

And in your Router:

```elixir
scope "/blog", alias: MyAppWeb, host: ["blog.mysite.com"] do
  pipe_through [:browser, :beacon]
  beacon_site "/", site: :blog
end
```

Note that `beacon_site` can only match requests coming from `"blog.mysite.com"` but
your site endpoint is binding to localhost, so it will never match. To fix it just
add `"localhost"` in the `:host` scope list:

```elixir
scope "/blog", alias: MyAppWeb, host: ["blog.mysite.com", "localhost"] do
```

2. Incorrect routes order

The macro `beacon_site` is a catch-all route defined as `/*` so you have to place
the most specific routes first, eg:

```elixir
scope "/", alias: MyAppWeb, host: ["blog.mysite.com"] do
  pipe_through [:browser, :beacon]
  beacon_site "/blog", site: :blog
  beacon_site "/", site: :my_site
end
```

The opposite would not work, the `:blog` would never match if placed after the `:my_site` site.

3. Missing `use Beacon.Router` and/or missing `beacon_site` in your app's router file.

Misconfiguration may also cause that error.

Also check the [Beacon.Router](https://hexdocs.pm/beacon/Beacon.Router.html) for more information.

## Could not resolve "tailwindcss/plugin"

Usually caused by having installed Tailwind v4 instead of Tailwind v3

Tailwind v4 doesn't have the `plugin` module and is not supported yet,
so make sure your `package.json` file specify `tailwindcss` 3.x

