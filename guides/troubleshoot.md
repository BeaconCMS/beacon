# Troubleshoot

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