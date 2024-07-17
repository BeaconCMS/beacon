# Tailwind Configuration

Pages can be styled with Tailwind by default, either with a custom config with plugins or using the default configuration. But there are some requirements to make it work properly on sites and also to preview pages on the Visual Editor.

## Requirements
* Tailwind v3.3.0 or higher is required
* Config module in ESM format
* Pre-bundled config if using plugins

Let's go through each requirement to help you set up a proper config for your sites.

### Tailwind v3.3.0 or higher

Most projects are using the [tailwind](https://hex.pm/packages/tailwind) library to download and invoke tailwind.
Just make sure the version meets the requirement. Upgrading is safe because Tailwind is very conservative about breaking changes.

### ESM format

Beacon uses Tailwind to generate stylesheets for published pages (your deployed site) and also to preview pages in the Visual Editor (in your admin interface).
The former uses the tailwind-cli binary (a node application) while the latter compiles the stylesheet in the browser, so we need to reuse the same config in both environments and ESM is the format that works in both environments.

Most Tailwind configs start in the CommonJS format, ie: exporting the config as `module.exports` and in most cases the only change you need to do is replace it with `export default`. Given a CommonJS config like the one below:

```js
module.exports = {
  theme: {
    colors: {
      'blue': '#1fb6ff'
    }
  }
}
```

Replace with the following to have a valid ESM config:

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

### Pre-bundled plugins

This step is optional if you're not using plugins or not requiring any external module in your config, but if you're requiring any plugin then you need to bundle everything together in a single module otherwise Beacon won't find those plugins at runtime.

We'll be using [esbuild](https://hex.pm/packages/esbuild) to bundle that module, which comes installed in any new recent Phoenix project, otherwise install it first.

Open the file `config/config.exs`, find the `:esbuild` config, and add a new `tailwind_config` that will look like this:

```elixir
config :esbuild,
  version: "0.23.0",
  default: [
    # omitted for brevity
  ],
  tailwind_config: [
    args: ~w(tailwind.config.js --bundle --format=esm --target=es2020 --outfile=../priv/tailwind.config.bundle.js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
```

Now you can execute `mix esbuild tailwind_config` to generate the file `priv/tailwind.config.bundle.js` which will bundle the config in `assets/tailwind.config.js` with all plugins.

You can see a demo at https://github.com/BeaconCMS/beacon_demo/tree/main/assets

The last step is using the bundled file as the `tailwind_config` in your site configuration:

```elixir
tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "tailwind.config.bundle.js"),
```

Remember to replace `:my_app` with your actual app name.
