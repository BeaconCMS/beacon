# Your First Site

## Pre-requisites

To get your first site up and running, you first need a working Phoenix application with Phoenix LiveView and also the Beacon LiveAdmin to create and manage resources for your site.

You need to follow the two guides below to get started:

- [Install Beacon](https://github.com/BeaconCMS/beacon/blob/main/guides/installation.md)
- [Install Beacon LiveAdmin](https://github.com/BeaconCMS/beacon_live_admin/blob/main/guides/installation.md)

Beacon can be installed on existing Phoenix applications, but make sure the minimum requirements are met as described in the installation guide.

## Generating the site

Each site requires some minimal configuratin to run, lets use the built-in `beacon.install` generator to get started quickly. In the root of your application, execute:

```
mix beacon.install --site my_site
```

You can use other name you like as long as you remember to change it in the following steps.

## Configuring the routes

In the `router.ex` file,  you'll see the following scope in a new Phoenix application:

```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  get "/", PageController, :home
end
```

Or something similar if you have changed it before. For this tutorial we are assuming the Beacon site will be mounted at the root `/` route,
so you can delete that block or change where the Beacon site is mounted, as long as you keep that in mind and adjust accordingly throughout the tutorial.

And finally change the generated scope created by Beacon to look like:

```elixir
scope "/" do
  pipe_through :browser
  beacon_site "/", site: :my_site
end
```

With this change the site will be served at [http://localhost:4000/](http://localhost:4000/)

## Connecting to a database

The `beacon.install` generator will change and create some files for you but the most important configuration at this point is adjusting the Repo credentials since Beacon requires a database to save layouts, pages, and all the site data.

Look for the config `config :beacon, Beacon.Repo` in the files `config/dev.exs` and `config/prod.exs` to make the database configuration looks correct to your environment.

## Acessing LiveAdmin to manage your site

We're done with configuration so far, let's run the project and access the LiveAdmin UI.

Firstly execute the following to install dependencies:

```sh
mix setup
```

And now start your Phoenix app:

```sh
mix phx.server
```

Visit http://localhost:4000/admin and you should see the `my_site` that you just created listed on the admin interface.

Now let's create the resources for our first site.

## Creating the home page

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
          <img
            src="http://localhost:4000/beacon_assets/demo/narwin.webp"
            alt="CMS Platform"
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

Save the changes and Publish the page. Go to http://localhost:4000 and you'll see an error! That's because we haven't created all resources used in that page yet. Let's fix it.

## Live Data

The current year is displayed at the footer as an assign `<%= @current_year %>` so we need to create such assign for our page.

Go to http://localhost:4000/admin/my_site/live_data to create a new path `/` and then create a new assign named `current_year` with the following value:

```elixir
Date.utc_today().year
```

Remember to change the Format to Elixir so that content can be evaluated as Elixir code.

Go to the home page again and refresh the page, it should render and you should see the current year displayed at the footer. But trying to submit the form to signup to the newsletter does nothing
and you can see on the console logs of your Phoenix server that Beacon tries to handle that event but it doesn't find any handler for it. Let's fix that.

## Event Handler

Edit the home page and click on the Events tab. There we'll create a new event handler for the form submission `join` defined in our home page template.

The name used in the template must match so create a new Event Handler named `join` with the following content:


```elixir
%{"waitlist" => %{"email" => email}} = event_params
IO.puts("#{email} joined the waitlist")
{:noreply, assign(socket, :joined, true)}
```

As you can see submiting the form will log the email to the console and set the `joined` assign to `true`, which is used to display a message to the user that the email was successfully submitted.
Let's see it working. Publish the page again and go back to the home page, fill the form and submit it.

--

Congratulations! You have a site up and running. The next step is to [deploy your site](https://github.com/BeaconCMS/beacon/blob/main/guides/recipes/deploy-to-flyio.md).