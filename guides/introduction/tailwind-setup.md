# Tailwind Setup

Beacon has built-in TailwindCSS support, any page can use its classes out of the box and a stylesheet will be automatically generated and served.

That default configuration is already bundled in the Beacon package, so you can skip this guide if that suits your needs.

Otherwise, keep reading to learn how to set up a custom configuration with more advanced features such as custom plugins plugins, themes, and more.

**Note** that the Tailwind configuration must respect some constraints to work properly with Beacon,
so if you want to reuse an existing configuration, make sure to follow the steps below and make the necessary adjustments.
It might be a good idea to keep separated configs, one for your application and another one for Beacon sites, and reuse
parts that are common between them.

## Objective

Make sure the proper Tailwind version is installed, create a valid Tailwind config in the ESM format, then bundle everything together in a single module.

## Requirements

A site must be already configured. Otherwise, follow the [Your First Site](https://hexdocs.pm/beacon/your-first-site.html) guide first.

## Constraints

Since Beacon uses the same configuration to generate stylesheets for your sites and also to preview pages on the Visual Editor in the browser,
that configuration must respect some constraints to work properly in both environments:

  - [Use the ESM format](https://tailwindcss.com/blog/tailwindcss-v3-3#esm-and-type-script-support)
  - Can't call node APIs such as `require("fs")` and `require("path")`

## Steps

* Install Tailwind v3.3.0 or higher
* Install Esbuild
* Create a new valid config
* Heroicons
* Install plugins
* Bundle the config
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
Any recent version that is installed should work just fine.

### Install plugins

The config we'll generate imports the plugins `@tailwindcss/forms` and `@tailwindcss/typography` that must be installed in order to generate the bundle file,
so execute in the root of your project:

```sh
npm install --prefix assets --save @tailwindcss/forms @tailwindcss/typography
```

### Create a new valid config file and update site config

Beacon provides a generator that will create and change the files needed to set up a custom Tailwind configuration.

Execute at the root of your project and follow the prompts:

```sh
mix beacon.gen.tailwind_config
```

The generated config file is in the ESM format, ie: it exports the config as `default export` instead of `module.exports`,
and it doesn't use node APIs like `fs` or `path`, so it can't bundle heroicons as the default Phoenix config does,
but Beacon provides a component to render such icons, see the [Heroicons guide](../recipes/heroicons.md) for more information.

## Site Configuration

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
         tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "beacon.tailwind.config.bundle.js") # <-- add this line
       ]
     ]},
    MyAppWeb.Endpoint
  ]

  # omitted for brevity
end
```