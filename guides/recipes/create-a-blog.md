# Create a Blog

## Objective

Create blog posts with custom fields (type and tags), render each one using the tailwind typography plugin, and list the most recent posts in an index page.

## Requirements

This guide will skip initial setup steps that are already covered in the [your first site guide](https://github.com/BeaconCMS/beacon/blob/main/guides/your-first-site.md),
so if that's the first site in your application, or you're not familiar with Beacon, please follow that guide first to make sure the environment is set up correctly:

- Beacon and Beacon LiveAdmin are installed
- A database migration exists to create the Beacon tables
- Router is already setup

## Create the blog site

Now that we have fullfilled the requirements, let's create the blog site mounted at `/blog`. Go ahead and execute:

```sh
mix beacon.install --site blog --path /blog
```

A basic site was just created but we have some work to do before executing the Phoenix server.

## Tailwind Configuration

Since we'll be using a tailwind plugin, you need to follow the [Tailwind configuration guide](https://github.com/BeaconCMS/beacon/blob/main/guides/tailwind-configuration.md)
to setup and bundle the tailwind configuration.

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

Visit http://localhost:4000/admin/blog/layouts, edit the Default layout, and change the template to:

```heex
<div>
  <header class="bg-background border-b">
    <div class="container mx-auto flex items-center justify-between h-16 px-4 md:px-6">
      <.page_link path={~p"/"} class="text-2xl font-bold">My Blog</.page_link>
      <nav class="hidden md:flex space-x-4">
        <.page_link path={~p"/"} class="text-muted-foreground hover:text-foreground transition-colors">Blog</.page_link>
        <.page_link path={~p"/about"} class="text-muted-foreground hover:text-foreground transition-colors">About</.page_link>
        <.page_link path={~p"/contact"} class="text-muted-foreground hover:text-foreground transition-colors">Contact</.page_link>
      </nav>
    </div>
  </header>
  <div :if={@beacon.page.path == "/"} class="container mx-auto px-4 py-12 md:px-6 lg:py-16">
    <%= @inner_content %>
  </div>

  <div :if={@beacon.page.path != "/" } class="container mx-auto px-4 py-12 md:px-6 lg:py-16 prose lg:prose-lg prose-slate">
    <%= @inner_content %>
  </div>
</div>
```

Some notes about this layout:
- The `prose` classes are defined by the tailwind typography plugin and is responsible for making our blog look good.
- Conditionally apply the `prose` classes only to the blog posts, not to the home page.

## Create the first blog post

Visit http://localhost:4000/admin/blog/pages and create a new page with the following data:

- Path: /the-elixir-language
- Title: The Elixir language
- Description: What's Elixir, how and where it can be used.
- Format: Markdown
- Type: Blog Post
- Tags: 2024,eng,elixir

And the following template:

```markdown
# The Elixir language

In the ever-evolving world of web development, Elixir has emerged as a powerful and innovative language that is transforming the way we build web applications. This blog post explores the unique features and benefits of Elixir, and how it can revolutionize your web development workflow.

## The Rise of Elixir

Elixir is a dynamic, functional programming language that runs on the Erlang Virtual Machine (BEAM). Inspired by Erlang, Elixir inherits its robust concurrency model, fault-tolerance, and scalability, making it an excellent choice for building highly available and scalable web applications.

One of the key features of Elixir is its focus on functional programming principles. By embracing immutable data structures and a concise syntax, Elixir enables developers to write more expressive and maintainable code. This, combined with Elixir's powerful metaprogramming capabilities, allows for the creation of domain-specific languages (DSLs) that can greatly enhance developer productivity.

## Elixir and Web Development

Elixir's strengths make it an excellent choice for web development. The Phoenix framework, which is often compared to Ruby on Rails, provides a robust and scalable foundation for building web applications. With its focus on real-time communication and fault-tolerance, Elixir and Phoenix are well-suited for building applications that require high availability and low latency, such as chat applications, real-time dashboards, and IoT platforms.

Here's an example of a simple Elixir web application using the Phoenix framework:

```elixir
# lib/my_app_web/controllers/page_controller.ex
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", message: "Welcome to Elixir!")
  end
```

## The Future of Elixir in Web Development

As Elixir and the Phoenix framework continue to evolve, we can expect to see even more exciting developments in the world of web development. Advancements in areas like real-time data processing, distributed systems, and seamless integration with other technologies will further enhance the capabilities of Elixir-based web applications.

By embracing Elixir, web developers can unlock new levels of scalability, fault-tolerance, and developer productivity, paving the way for a future where the focus is on building innovative and user-centric web experiences, rather than managing complex infrastructure.
```

Save and publish this page. Now visit http://localhost:4000/blog/the-elixir-language to see the result. There is your first blog post!

## Create the blog index

Now that we have a blog post, let's create an index page to list published posts.

First we need to fetch published posts, so let's create a live data assign that exposes data to pages. Visit http://localhost:4000/admin/blog/live_data,
create a new live data for the path `/`, and then create a new assign `most_recent_posts` with the following code:

```elixir
import Ecto.Query

Beacon.Content.list_published_pages(
  :blog,
  search: fn -> dynamic([q], fragment("extra->>'type' = 'blog_post'"))
end)
```

Visit http://localhost:4000/admin/blog/pages and edit the "My Home Page" with the following data:

- Title: My Blog
- Type: Page
- Tags: leave empty (no tags)

And the following template:

```heex
<div class="mb-8">
  <h2 class="text-lg font-medium text-muted-foreground">
    Welcome to My Blog
  </h2>
  <p class="text-muted-foreground">
    Discover the latest insights and trends in web development, design, and technology.
  </p>
</div>

<h1 class="text-3xl font-bold mb-8 md:text-4xl text-primary">Latest Blog Posts</h1>

<div class="grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
  <div :for={post <- @most_recent_posts} class="bg-background rounded-lg overflow-hidden shadow-sm transition-all hover:shadow-lg">
    <div class="p-6">
      <.page_link path={~p"#{post}"} class="text-xl font-bold mb-2 block text-primary">
        <%= post.title %>
      </.page_link>
      <div class="flex flex-wrap gap-2 mb-2">
        <div
          :for={tag <- String.split(post.extra["tags"], ",")}
          class="inline-flex w-fit items-center whitespace-nowrap rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80">
          <%= tag %>
        </div>
      </div>
      <p class="text-muted-foreground">
        <%= post.description %>
      </p>
    </div>
  </div>
</div>
```

Save the changes and publish the page. Visist http://localhost:4000/blog to see the result!