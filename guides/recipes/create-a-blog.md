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
Any recent version that is installed should work just fine.

## Create the blog site

Now that we have fullfilled the requirements, let's create the blog site mounted at `/blog`. Go ahead and execute:

```sh
mix beacon.install --site blog --path /blog
```

A basic site was just created but we have some work to do before executing the Phoenix server.

## Tailwind Configuration

Now that your site is created, you can add the `:tailwind_config` in your site configuration as explained at the end of the [Tailwind configuration guide](https://github.com/BeaconCMS/beacon/blob/main/guides/tailwind-configuration.md).

## Tailwind Typography Plugin

A blog is useless if it looks ugly and is hard to read but lucky us that Tailwind provides a [plugin](https://tailwindcss.com/blog/tailwindcss-typography) that turns blocks of HTML into beautiful documents.

Let's install that plugin. Execute in the root of your project:

```sh
npm install --prefix assets --include=dev @tailwindcss/typography
```

And edit the file `assets/tailwind.config.js` to require that plugin. Add the following line in the `plugins` list:

```js
require("@tailwindcss/typography"),
```

## Custom Fields

Every Beacon page has some essential fields like title, path, description, and others. But since Beacon can be used to build any kind of site, from small to big,
we can't include all possible fields to accomodate all kinds of page that might exist. The solution to this problem is allowing users to create their own custom field,
which are displayed in the Beacon LiveAdmin editor, stored in the page record in the database, and can be used in queries and templates.

For our blog we'll create 2 custom fields: type and tags. Type to allow us to distinguish between a regular page and a blog post, and tags to allow us to categorize our posts.

Those custom fields are modules that implements the `Beacon.Content.PageField` behaviour. Let's create them.

### Custom field `type`

Create a new file `lib/my_app/beacon/page_fields/type.ex` with the following content:

```elixir
defmodule MyApp.Beacon.PageFields.Type do
  @moduledoc """
  Custom beacon page field to distinguish between a regular page and a blog post.
  """

  use Phoenix.Component
  import BeaconWeb.CoreComponents
  import Ecto.Changeset

  @behaviour Beacon.Content.PageField

  @impl true
  def name, do: :type

  @impl true
  def type, do: :string

  @impl true
  def default, do: "page"

  @impl true
  def render(assigns) do
    assigns = Map.put(assigns, :opts, [{"Page", "page"}, {"Blog Post", "blog_post"}])

    ~H"""
    <.input type="select" label="Type" prompt="Choose type" options={@opts} field={@field} />
    """
  end

  @impl true
  def changeset(data, attrs, %{page_changeset: _page_changeset}) do
    cast(data, attrs, [:type])
  end
end
```

Note that the file location and the module name doesn't need to follow any special convention, it's up to you to organize your code as you see fit.

### Custom field `tags`

A blog post without tags is like a cake without icing, so let's create a custom field to store list of tags for each post.

```elixir
defmodule MyApp.Beacon.PageFields.Tags do
  @moduledoc """
  Custom beacon page field to store tags for a blog post.

  Tags are separated by commas.
  """

  use Phoenix.Component
  import BeaconWeb.CoreComponents
  import Ecto.Changeset

  @behaviour Beacon.Content.PageField

  @impl true
  def name, do: :tags

  @impl true
  def type, do: :string

  @impl true
  def default, do: "2024"

  @impl true
  def render(assigns) do
    ~H"""
    <.input type="text" label="Tags" field={@field} />
    """
  end

  @impl true
  def changeset(data, attrs, _metadata) do
    cast(data, attrs, [:tags])
  end
end
```

Great, now we need to tell Beacon to use those custom page fields. Open the file `lib/my_app/application.ex` and add the following into your site configuration:

```elixir
extra_page_fields: [
  MyApp.Beacon.PageFields.Type,
  MyApp.Beacon.PageFields.Tags
]
```

## Create the layout

It's time to spin up the server, access the admin interface, and create the resources of our site. Execute:

```sh
mix phx.server
```

And access http://localhost:4000/admin/blog/layouts

