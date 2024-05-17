# Add Custom Page Fields

Every Beacon page contains a set of pre-defined fields that behaves the same way across all pages, for example the Title and Description fields are used to fill meta tags for SEO purposes, and so on. And that's the same behavior on all pages.

But often you need to store custom data, perform some logic on that data, or display extra information on the page. Some examples include tags for blog posts, authors, links, and so on.

In this recipe we'll add a custom page field `Type` to allow users identify the type of the page on the admin interface and use that data to list recent blog posts.

## Add a module that implements the `Beacon.Content.PageField` behavior

In this module we'll define how the data is stored and validated, and how the field is displayed on the admin interface. Create a file with this content:

```elixir
defmodule MyApp.Beacon.PageFields.Type do
  @moduledoc false
  @behaviour Beacon.Content.PageField

  use Phoenix.Component
  import BeaconWeb.CoreComponents
  import Ecto.Changeset

  @impl true
  def name, do: :type

  @impl true
  def type, do: :string

  @impl true
  def default, do: "page"

  @impl true
  def changeset(data, attrs, %{page_changeset: _page_changeset}) do
    cast(data, attrs, [:type])
  end

  @impl true
  def render(assigns) do
    assigns = Map.put(assigns, :opts, [{"Page", "page"}, {"Blog Post", "blog_post"}])

    ~H"""
    <.input type="select" label="Type" prompt="Choose type" options={@opts} field={@field} />
    """
  end
end
```

Let's break down each part of the module:

* `name` can be any atom that represents the field name, for example `:tags` for a lists of tags or `:author_id` to store a reference to the page author.
* `type` any valid [Ecto Schema type](https://hexdocs.pm/ecto/Ecto.Schema.html#module-types-and-casting)
* `default` pre-populate the field with this value
* `changeset` is where you can add your own validation logic to that field, `page_changeset` is the changeset for the `%Beacon.Content.Page{}` itself
* `render` implement the template to display the field on the page editor on the admin interface

## Access the field content

Once a page is created or updated with that custom field, the content will be stored in the `:extra` field of the `%Beacon.Content.Page{}` record under the name of the custom field,
in our example a page with type `blog_post` would look like this:

```elixir
%Beacon.Content.Page{
  # ...
  extra: %{"type" => "blog_post"},
}
```

You can make use of that field to filter pages or display that extra information on the page template.