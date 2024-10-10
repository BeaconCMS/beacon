# On Mount Handle Info Loop

Using [Live Data](https://hexdocs.pm/beacon/0.1.0-rc.2/Beacon.Content.html#create_live_data/1) assigns, [on_mount](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1) callbacks, and  corresponding [handle_info](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:handle_info/2) handlers is a pattern that you can leverage to achieve optimistic UI for your pages.

Suppose you're displaying a Weather widget on your page but fetching the data takes a second, delaying the whole page, even though that widget is not critical to your page and could display dummy data (or no data at all) while the rest of the page is loaded. In this scenario, a Live Data assign would provide the initial dummy data, the on_mount hook request the data to be loaded asyncly, and finally the handle_info loads the data and update that assign.

For this example, we'll build a similar scenario but also add a continuous monitor to update the assign frequently.

In this example we're going to update a `DateTime` every `1_000` milliseconds from the server, starting that loop `on_mount`, then continuously looping over a `handle_info`.

## Creating the On Mount Handler Module

After completing [your first site](../introduction/your-first-site.md) guide, create a module to handle 
your `on_mount` callbacks. This is an example, so find a place that works best 
for your project structure. Here, we're creating a `my_site_on_mount.ex` file
in our web path.

```bash
├── lib
│   ├── my_site
│   ├── my_site_web
│   │   ├── components
│   │   │   ├── core_components.ex
│   │   │   ├── layouts
│   │   │   │   ├── app.html.heex
│   │   │   │   └── root.html.heex
│   │   │   ├── callbacks
│   │   │   │   └── my_site_on_mount.ex
│   │   │   └── layouts.ex
│   │   ├── controllers
│   │   │   ├── error_html.ex
│   │   │   ├── error_json.ex
│   │   │   ├── page_controller.ex
│   │   │   ├── page_html
│   │   │   │   └── home.html.heex
│   │   │   └── page_html.ex
│   │   ├── endpoint.ex
│   │   ├── gettext.ex
│   │   ├── router.ex
│   │   └── telemetry.ex
│   └── my_site_web.ex
```

When the socket is connected, we will send a message to `self()` in 1_000 milliseconds
to `:update_current_time`. 

```elixir
defmodule MySiteWeb.OnMount do
  use MySiteWeb, :live_view

  def on_mount(_path, _params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :update_current_time, 1_000)
    end

    {:cont, socket}
  end
end
```

## Updating the Live Session

In your `router.ex` file, add the `on_mount` option to your `my_site` route so it is handled in the live session.

```elixir
scope "/" do
    pipe_through :browser
    beacon_site "/",
      site: :my_site,
      on_mount: {MySiteWeb.OnMount, []}
  end
```
## Accessing LiveAdmin to manage your site

Let's customize the home page. Visit http://localhost:4000/admin and you should see the `my_site` that you just created listed on the admin interface.

Now let's create the resources for our first site, and we'll starting by creating the resources used by the home page before we customize its template.

## Live Data

We want to display the current time on the home page as the assign `<%= @current_time %>`. In Beacon we use Live Data to create and modify assigns at runtime, let's do it.

Go to http://localhost:4000/admin/my_site/live_data and navigate to the "/" path and create a new assign named `current_time` using the `elixir` format with the following value:

```elixir
DateTime.now!("Etc/UTC")
```

Save the changes.

## Handle the :update_current_time info callback

Besides displaying some data, we will have a form to subscribe people to our newsletter, so we need to react to that event. Let's create an event handler for that.

Go to http://localhost:4000/admin/my_site/info_handlers and create a new event handler named `update_current_time` with the following content:

```elixir
Process.send_after(self(), :update_current_time, 1000)

{:noreply, assign(socket, current_time: DateTime.now!("Etc/UTC"))}
```
## Update the home page template

Finally, let's update the home page template to make use of the info handler we created.

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
      <p>©<%= @current_time %> <%= @current_year %> CMS Platform. All rights reserved.</p>
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

You should see `DateTime` updating every `1_000` milliseconds from the server.

