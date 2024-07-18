# Tailwind Configuration

Pages can be styled with Tailwind by default, either with a custom config with plugins or using the default configuration.
But there are some requirements to make it work properly on sites and also to preview pages on the Visual Editor.

## Objective

Make sure the proper Tailwind version is installed, create a Tailwind config in the ESM format, and if you intend to use plugins, then bundle everything together in a single module.

## Steps

* Install Tailwind v3.3.0 or higher
* Install Esbuild
* Create a Tailwind config or change it to ESM format
* Bundle the config with plugins
* Use the config in your site configuration

Let's go through each one to set up Tailwind properly for your sites.

### Tailwind v3.3.0 or higher

Any recent Phoenix application should have the [tailwind](https://hex.pm/packages/tailwind) library already installed and updated but let's double check by executing:

```sh
mix run -e "IO.inspect Tailwind.bin_version()"
```

If it fails or the version is lower than 3.3.0 then follow the [tailwind install guide](https://github.com/phoenixframework/tailwind?tab=readme-ov-file#installation)
to get it installed or updated. It's important to install a recent Tailwind version higher than 3.3.0

### Esbuild

Similar to Tailwind, any recent Phoenix application should have it installed already but let's check by executing:

```sh
mix run -e "IO.inspect Esbuild.bin_version()"
```

If it fails then follow the [esbuild install guide](https://github.com/phoenixframework/esbuild?tab=readme-ov-file#installation) to get it installed.

### Config in the ESM format

You can either use the same config file created by Phoenix generators or create a separate file only for Beacon sites. For this guide we'll create a new file `assets/tailwind.beacon.config.js` with the following content:

```js
default export {
  content: [
  ],
  theme: {
    extend: {
      colors: {
      }
    },
  },
  plugins: [
  ]
}
```

Note that we're using the ESM format, ie: `default export` instead of `module.exports`. That's because Beacon uses Tailwind to generate stylesheets for published pages (your deployed site) and also to preview pages in the Visual Editor (in your admin interface).
The former uses the tailwind-cli binary (a node application) while the latter compiles the stylesheet in the browser, so we need to reuse the same config in both environments and ESM is the format that works in both environments.

If you're using an existing config, it most likely will be in the CommonJS format, so given a file like this:

```js
module.exports = {
  theme: {
    colors: {
      'blue': '#1fb6ff'
    }
  }
}
```

Replace how the module is exported to have a valid ESM config:

```js
export default {
  theme: {
    colors: {
      'blue': '#1fb6ff'
    }
  }
}
```

More info at https://tailwindcss.com/blog/tailwindcss-v3-3#esm-and-type-script-support

### Bundled config

We'll change 3 files to make it work:

1. `config/config.exs`

Open the file `config/config.exs`, find the `:esbuild` config, and add a new `tailwind_bundle` that will look like this:

```elixir
config :esbuild,
  version: "0.23.0",
  my_app: [
    # omitted for brevity
  ],
  # add this block
  tailwind_bundle: [
    args: ~w(tailwind.beacon.config.js --bundle --format=esm --target=es2020 --outfile=../priv/tailwind.beacon.config.bundle.js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
```

2. `config/dev.exs`

Open the file `config/dev.exs`, find the `:watchers` key in the endpoint config, and add a new `tailwind_bundle` that will look like this:

```elixir
config :my_app, MyAppWeb.Endpoint,
  # omitted for brevity
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
    esbuild: {Esbuild, :install_and_run, [:tailwind_bundle, ~w(--watch)]}, # add this line
    tailwind: {Tailwind, :install_and_run, [:my_app, ~w(--watch)]}
  ]
```

3. `mix.exs`

In the list of aliases, add the following command in both `"assets.build"` and `"assets.deploy"`:

```elixir
"esbuild tailwind_bundle"
```

It will look like this:

```elixir
defp aliases do
  [
    # omitted for brevity
    "assets.build": ["tailwind my_app", "esbuild my_app", "esbuild tailwind_bundle"],
    "assets.deploy": [
      "tailwind my_app --minify",
      "esbuild my_app --minify",
      "esbuild tailwind_bundle",
      "phx.digest"
    ]
  ]
end
```

## Site Configuration

Open the file `lib/my_app/application.ex` (replace my_app with your actual application name), find the configuration of the site you'll be using
this Tailwind config and add the `tailwind_config` key pointing to the bundled file:

```elixir
tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "tailwind.beacon.config.bundle.js"),
```

It will look somewhat like this:

```elixir
@impl true
def start(_type, _args) do
  children = [
    # omitted for brevity
    {Beacon,
     sites: [
       [
         site: :my_site,
         repo: MyApp.Repo,
         endpoint: MyAppWeb.Endpoint,
         router: MyAppWeb.Router,
         tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "tailwind.beacon.config.bundle.js") # add this line
       ]
     ]},
    MyAppWeb.Endpoint
  ]

  # omitted for brevity
end
```

**Note:** Remeber to replace _my_app_ with the actual name of your application.