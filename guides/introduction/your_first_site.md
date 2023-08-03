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

Beacon has built-in support for Tailwind classes and we'll be using the [Flowbite](https://flowbite.com/docs/) components to style our page but you're free to use any tool or design system you want.

Click on the "Layouts" button, then "Create New Layout". On this page we'll create the layout where all pages will be rendered. It will contain a footer, header, and the placeholder to render page's content.

Input "Main" for title and the following template:

```heex
<nav class="bg-white border-gray-200 dark:bg-gray-900">
  <div class="max-w-screen-xl flex flex-wrap items-center justify-between mx-auto p-4">
    <a href="/" class="flex items-center">
      <span class="self-center text-2xl font-semibold whitespace-nowrap dark:text-white">My Site</span>
    </a>
    <button data-collapse-toggle="navbar-default" type="button" class="inline-flex items-center p-2 w-10 h-10 justify-center text-sm text-gray-500 rounded-lg md:hidden hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-600" aria-controls="navbar-default" aria-expanded="false">
        <span class="sr-only">Open main menu</span>
        <svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 17 14">
            <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M1 1h15M1 7h15M1 13h15"/>
        </svg>
    </button>
    <div class="hidden w-full md:block md:w-auto" id="navbar-default">
      <ul
        class="font-medium flex flex-col p-4 md:p-0 mt-4 border border-gray-100 rounded-lg bg-gray-50 md:flex-row md:space-x-8 md:mt-0 md:border-0 md:bg-white dark:bg-gray-800 md:dark:bg-gray-900 dark:border-gray-700">
        <li>
          <a href="#"
            class="block py-2 pl-3 pr-4 text-white bg-blue-700 rounded md:bg-transparent md:text-blue-700 md:p-0 dark:text-white md:dark:text-blue-500"
            aria-current="page">Home</a>
        </li>
      </ul>
    </div>
  </div>
</nav>

<%= @inner_content %>
```

The `@inner_content` is important here, it's where page's templates will be injected into the layout.

Save the changes and Publish it.

## Creating the home page

For the home page we'll display an image uploaded to the Media Library. Firstly, go to [http://localhost:4000/admin/my_site/media_library](http://localhost:4000/admin/my_site/media_library), click "Upload", and finish by uploading an image that you like. On the list of assets, click "View", and on the bottom of the modal that has opened you'll find the path for that asset, copy it.

Go to [http://localhost:4000/admin/my_site/pages/new](http://localhost:4000/admin/my_site/pages/new) and input some data into the form:

* Path: leave it empty, that will be the root home page
* Title: Home - My Site
* Template:

```heex
<div class="h-screen mt-20">
  <img src="URL_OF_ASSET_HERE" class="mx-auto" />
</div>
```

Replace `URL_OF_ASSET_HERE`, save the changes, and publish the page.

Go ahead and visit [http://localhost:4000](http://localhost:4000) - that's your first published page!

## Creating the contact page

Let's add some interaction creating a contact form in a new page. Go to [http://localhost:4000/admin/my_site/pages/new](http://localhost:4000/admin/my_site/pages/new) again and input this data:

* Path: contact
* Title: Contact - My Site
* Template:

```heex
TODO
```

Save the changes and Publish it.

Go ahead and visit [http://localhost:4000](http://localhost:4000/contact). You'll see the form, the frontend is done, but it won't work since it needs to handle the form submit event.

LiveAdmin doesn not support managing Page Events at this moment so let's create it manually. Open another terminal in the root of the project and execute:

```sh
iex -S mix
```

And paste this code:

```elixir
TODO update page event
```

Done. Go ahead and test the content form.

## Improving SEO

Beacon is very focused on SEO and it's optimized to render pages as fast as possible, but that alone is not enough to perform well on search engines. On the Page Editor you can add Meta Tags and a Schema to provide extra info used by search engines crawling the page.

### Meta Tags

The title and description are two essential pieces of information that every page must have, and even though title is not a meta tag per se it goes along with the description for SEO purposes. Both are automatically added to your page when you fill the Title and Description fields in the Page Editor form.

In the era of social media it's important to add [Open Graph](https://ogp.me) meta tags to enrich your pages with link previews and extra information. Edit your page, go to "Meta Tags" tab and add a couple of meta tags:

| property       | content                 |
| -------------- | ----------------------- |
| og:title       | {{ page.title }}        |
| og:description | {{ page.description }}  |

Many other meta tags can be added depending on the type and content of the page, but those are good to get started.

Save the changes.

## Schema

[Strutured Data](https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data) can be added to help search engines undertand the content of the page. Go to the "Schema" tab and input this content in the code editor:

```json
[
  {
    "@context": "https://schema.org",
    "@type": "Organization",
    "url": "https://www.my_site.com",
    "logo": "https://www.my_site.com/images/logo.png"
  }
]
```

Replace the URL with a domain you own if you intend to deploy your site.

Note that content can be a single object or a list of objects as necessary.

Save the changes.




