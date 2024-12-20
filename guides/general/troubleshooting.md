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

Depending on the [deployment topology](https://hexdocs.pm/beacon/deployment-topology.html) and your router configuration,
a site prefix can never match and it will never receive requests.

That's is not necessarily an error if you have multiple sites in the same project
and each scope is filtering requests on the `:host` option.
But it may indicate:

1. An invalid configuration, as a preceding route matching the prefix
that was supposed to be handled by this site, or an invalid `:host` value.

2. Missing `use Beacon.Router` and/or missing `beacon_site` in your
app's router file.

Note that if you're using `:host` on the scope and running in `localhost`,
consider adding `"localhost"` to the list of allowed hosts.

Also check the [Beacon.Router](https://hexdocs.pm/beacon/Beacon.Router.html) for more information.

## RuntimeError - could not find persistent term for endpoint

`Beacon` should be started after your host's `Endpoint`, please review the application children
and make sure is declared after the endpoint.
