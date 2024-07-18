# Create a blog

## Objective

Create a blog with an index page listing the most recent posts in chronological order, create posts with tags, and render each one using the tailwind typography plugin.

## Requirements

You'll need to perform some steps before proceeding with this guides:

1. Install Beacon and Beacon LiveAdmin

Follow the [Beacon installation guide](https://github.com/BeaconCMS/beacon/blob/main/guides/installation.md) to set up both libraries in a Phoenix LiveView application.
Skip if Beacon and Beacon LiveAdmin are already installed.

2. Tailwind

Tailwind must be updated and the config file must be in the ESM format.

Follow the [Tailwind configuration guide](https://github.com/BeaconCMS/beacon/blob/main/guides/tailwind-configuration.md) to set up it properly.

2. Esbuild

Similar to Tailwind, any recent Phoenix application should have it installed already but let's check by executing:

```sh
mix run -e "IO.inspect Esbuild.bin_version()"
```

If it fails then follow the [esbuild install guide](https://github.com/phoenixframework/esbuild?tab=readme-ov-file#installation) to get it installed.

## Create the blog site

Now that we have fullfilled the requirements, let's create the blog site mounted at `/blog`. Go ahead and execute:

```sh
mix beacon.install --site blog --path /blog
```

A basic site was just created but we have some work to do before executing the Phoenix server.

## Tailwind Typography Plugin

A blog is useless if it looks ugly and is hard to read but lucky us that Tailwind provides a [plugin](https://tailwindcss.com/blog/tailwindcss-typography) that turns blocks of HTML into beautiful documents.

Let's install that plugins. Execute in the root of your project:

```sh
npm install --prefix assets --include=dev @tailwindcss/typography
```

Now edit the file assets/tailwind.config.js to require that plugin. Add the following line in the `plugins` list:

```js
TODO
```

The whole file should look like this:

```js
TODO
```

## Tags custom field

## Pages