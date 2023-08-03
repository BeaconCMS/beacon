# Your First Site

In this guide we'll walk trough all the steps necessary to have a functioning site with components, styles, and a contact form to demonstrate how Beacon works.

It's required that you have a working Phoenix LiveView with Beacon and Beacon LiveAdmin installed and configured correctly, please follow the [Beacon installation guide](https://github.com/BeaconCMS/beacon/blob/main/guides/introduction/installation.md) and [Beacon LiveAdmin installation guide](https://github.com/BeaconCMS/beacon_live_admin/blob/main/guides/introduction/installation.md) if you're starting from stratch.

## Generating the site

Each site requires some minimal configuratin to run in your application, lets use the built-in `beacon.install` generator to get started quickly. In the root of your application, execute:

```
mix beacon.install --site my_site
```

You can use whatever name you like as long as you remember to change it in the following steps.

## Configuring the routes

First of all delete the following scope added by Phoenix automatically:

```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  get "/", PageController, :home
end
```

Also feel free to delete page_controller.ex and related files, you won't need it.

And finally change the generated scope created by Beacon to look like:

```elixir
scope "/" do
  pipe_through :browser
  beacon_site "/", site: :my_site
end
```

With this change the site will be served at [http://localhost:4000/](http://localhost:4000/)

## Connecting to a database

The install generator will change and create some files for you but the most important configuration at this point is adjusting the Repo credentials since Beacon requires a database to store layouts, pages, and all site data.

Inspect the config `config :beacon, Beacon.Repo` in the file `config/dev.exs` and make sure it looks correct to your environment.

## Acessing LiveAdmin to manage your site

We're done with configuration so far, let's run the project and access the LiveAdmin UI.

Firstly execute to install dependencies:

```sh
mix setup
```

And now start your Phoenix app:

```sh
mix phx.server
```

Visit [http://localhost:4000/admin](http://localhost:4000/admin) and you should see `my_site` listed.

## Creating a layout

Click on the "Layouts" button, then "Create New Layout". On this page we'll create the layout where all pages will be rendered. It will contain a footer, header, and the placeholder to render page's content.


Input "Main" for title and the following template:

```heex
<header>TODO</header>
<%= @inner_content %>
<footer>TODO</footer>
```

Save the changes and Publish it.

## Creating a page

Now let's create the first page using the layout you just published. The content of this page will be rendered between the header and footer, in the `@inner_content` placeholder.

Go to "Pages", click "Create New Page", and input some data into the form:

* Path: leave it empty, that will be the root home page
* Title: Home Page - or be creative with it.
* Template:

```heex
<div>TODO</div>
```

Save the changes and Publish it.

Go ahead and visit [http://localhost:4000](http://localhost:4000) that's your first published page! Now dive into improving that page with more features.

## Adding a contact form

## Improving SEO
