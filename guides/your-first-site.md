# Your First Site

## Objective

Create your first site to get familiar with the install command and the most common operations to manage your site.

## Requirements

In order to create and serve sites, you'll need a Phoenix LiveView application with both Beacon and Beacon LiveAdmin installed.

Follow the [Beacon installation guide](https://github.com/BeaconCMS/beacon/blob/main/guides/installation.md) to set up the environment before proceeding with this guide.

## Setup the database schema

Site data is stored in the database so we need to create the necessary tables first. Let's use a Ecto migration to perform this task. Execute:

```sh
mix ecto.gen.migration create_beacon_tables
```

Then go to the generated migration (usually in `/priv/repo/migrations`) and change the migration to look like this:

```elixir
defmodule MyApp.Repo.Migrations.CreateBeaconTables do
  use Ecto.Migration
  defdelegate up, to: Beacon.Migration
  defdelegate down, to: Beacon.Migration
end
```

## Generating the site

Now it's time to create your first site. You need to change some files in your application but Beacon provides a generator to help you with that.

In the root of your application, execute:

```sh
mix beacon.install --site my_site --path /
```

## Configuring the routes

To access the admin interface and the site we just created, both needs to be mounted in your application router. Open the file `router.ex` and change it to look like this:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Beacon.LiveAdmin.Plug
  end

  use Beacon.Router
  use Beacon.LiveAdmin.Router

  scope "/admin" do
    pipe_through :browser
    beacon_live_admin "/"
  end

  scope "/" do
    pipe_through :browser
    beacon_site "/", site: :my_site
  end
end
```

Replace `MyApp` with your application name.

For the sake of simplicity of this guide we're assuming that no other route is available, but if you intend to have more routes in your application,
you have to pay attention to the order in which the routes are defined, see the `Beacon.Router` module for more information.

## Starting the application

We're done configuring your site, let's run the project to make sure it's working.

Firstly execute the following to install dependencies:

```sh
mix setup
```

And now start your Phoenix app:

```sh
mix phx.server
```

Visit http://localhost:4000 to see the default home page created by Beacon.

## Acessing LiveAdmin to manage your site

Let's customize the home page. Visit http://localhost:4000/admin and you should see the `my_site` that you just created listed on the admin interface.

Now let's create the resources for our first site, and we'll starting by creating the resources used by the home page before we customize its template.

## Live Data

We want to display the current yeat at the footer of the home page as the assign `<%= @current_year %>`. In Beacon we use Live Data to create and modify assigns at runtime, let's do it.

Go to http://localhost:4000/admin/my_site/live_data to create a new path `/` and then create a new assign named `current_year` using the `elixir` format with the following value:

```elixir
Date.utc_today().year
```

Save the changes.

## Handle the form submission event

Besides displaying some data, we will have a form to subscribe people to our newsletter, so we need to react to that event. Let's create an event handler for that.

Go to http://localhost:4000/admin/my_site/pages, click on the Home Page, and click on the Events tab on the top of the page. Then create a new event handler `join` with the following content:

```elixir
%{"waitlist" => %{"email" => email}} = event_params
IO.puts("#{email} joined the waitlist")
{:noreply, assign(socket, :joined, true)}
```

## Upload an image

The last resource we want in our home is an image. Beacon provides a Media Library to upload and serve images, so first find an image and rename it to `image.jpg` (or the extension you prefer). Or use one of the images in https://github.com/BeaconCMS/beacon/tree/main/assets/images

Go to http://localhost:4000/admin/my_site/media_library and upload that image.

## Update the home page template

Finally, let's update the home page template to make use of the live data, the event handler, and the image we just uploaded.

Go to http://localhost:4000/admin/my_site/pages and you should see a page already created for the `/` path. We're going to change it.

Edit the template to replace with this content:

```heex
<div class="relative flex min-h-[100dvh] flex-col overflow-hidden bg-gradient-to-br from-[#0077b6] to-[#00a8e8] text-white">
  <div class="absolute inset-0 z-[-1] bg-cover bg-center opacity-30 blur-[100px]"></div>
  <header class="container mx-auto flex items-center justify-between py-6 px-4 md:px-6">
    <div class="flex items-center gap-2">
      <.link patch="/" class="flex items-center gap-2">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="h-8 w-8"
        >
          <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"></path>
          <line x1="4" x2="4" y1="22" y2="15"></line>
        </svg>
        <span class="text-2xl font-bold">CMS Platform</span>
      </.link>
    </div>
    <div class="flex items-center gap-4">
      <.link patch="/blog" class="hidden md:inline-flex text-sm font-medium hover:underline">
        Blog
      </.link>
      <button class="items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-secondary text-secondary-foreground hover:bg-secondary/80 h-10 px-4 py-2 hidden md:inline-flex">
        Sign In
      </button>
    </div>
  </header>
  <main class="container mx-auto flex-1 px-4 md:px-6">
    <div class="mx-auto max-w-6xl space-y-6 py-12 md:py-24 lg:py-32">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div class="space-y-6">
          <h1 class="text-4xl font-bold leading-tight md:text-5xl lg:text-6xl">
            <span class="bg-gradient-to-r from-[#00a8e8] to-[#0077b6] bg-clip-text text-[#333] dark:text-white">
              Unlock the power
            </span>
            of your content with our CMS platform
          </h1>
          <p class="text-lg text-gray-300 md:text-xl">
            Streamline your content management with our intuitive, high-performance CMS built on Phoenix LiveView.
          </p>
          <Phoenix.Component.form :let={f} for={%{}} as={:waitlist} phx-submit="join">
            <div class="flex w-full max-w-2xl items-center space-x-2">
              <input
                id={Phoenix.HTML.Form.input_id(f, :email)}
                name={Phoenix.HTML.Form.input_name(f, :email)}
                class="flex h-10 w-full border border-input text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 flex-1 rounded-md border-none bg-white/10 py-3 px-4 text-white placeholder:text-gray-300 focus:ring-2 focus:ring-[#00a8e8]"
                placeholder="Enter your email"
                type="email"
              />
              <button
                class="inline-flex items-center justify-center whitespace-nowrap text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 text-primary-foreground h-10 rounded-md bg-[#00a8e8] py-3 px-6 font-medium transition-colors hover:bg-[#0077b6]"
                type="submit"
              >
                Join Waitlist
              </button>
            </div>
          </Phoenix.Component.form>
          <span :if={Map.get(assigns, :joined)} class="text-sm text-gray-300">
            Congrats! You joined the watchlist.
          </span>
        </div>
        <div class="flex items-center justify-center">
          <.image
            site={@beacon.site}
            name="image.webp"
            alt="My Page Image"
            width="600"
            height="600"
            style="aspect-ratio: 600 / 600; object-fit: cover;"
          />
        </div>
      </div>
    </div>
  </main>
  <footer class="container mx-auto border-t border-white/20 py-6 px-4 text-sm text-gray-300 md:px-6">
    <div class="flex items-center justify-between">
      <p>© <%= @current_year %> CMS Platform. All rights reserved.</p>
      <div class="flex space-x-4 items-center">
        <a class="hover:underline" href="#">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="h-5 w-5"
          >
            <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"></path>
          </svg>
          <span class="sr-only">Facebook</span>
        </a>
        <a class="hover:underline" href="#">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="h-5 w-5"
          >
            <path d="M22 4s-.7 2.1-2 3.4c1.6 10-9.4 17.3-18 11.6 2.2.1 4.4-.6 6-2C3 15.5.5 9.6 3 5c2.2 2.6 5.6 4.1 9 4-.9-4.2 4-6.6 7-3.8 1.1 0 3-1.2 3-1.2z">
            </path>
          </svg>
          <span class="sr-only">Twitter</span>
        </a>
        <a class="hover:underline" href="#">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="h-5 w-5"
          >
            <rect width="20" height="20" x="2" y="2" rx="5" ry="5"></rect>
            <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"></path>
            <line x1="17.5" x2="17.51" y1="6.5" y2="6.5"></line>
          </svg>
          <span class="sr-only">Instagram</span>
        </a>
        <a class="hover:underline" href="#">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="h-5 w-5"
          >
            <path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z">
            </path>
            <rect width="4" height="12" x="2" y="9"></rect>
            <circle cx="4" cy="4" r="2"></circle>
          </svg>
          <span class="sr-only">LinkedIn</span>
        </a>
        <a class="hover:underline" href="#">
          Privacy
        </a>
        <a class="hover:underline" href="#">
          Terms
        </a>
        <a class="hover:underline" href="#">
          Contact
        </a>
      </div>
    </div>
  </footer>
</div>
```

Save the changes and Publish the page. Go to http://localhost:4000 to check the final result!

You should see the image you uploaded, the current year on the footer, and a message after joining the waitlist.

-----------------------

Congratulations! You have a site up and running.

Check out all available [recipes](https://github.com/BeaconCMS/beacon/blob/main/guides/recipes/) to learn how to deploy your site, customize it even further, and more.
