# Basic app authentication

If you want to protect your app with a basic username and password protection, you can easily do so by using the [`Plug.BasicAuth`](https://hexdocs.pm/plug/Plug.BasicAuth.html) plug.

Plugs in Phoenix are basically functions that get a `Plug.Conn` instance (which is basically _the whole universe_ of your app's request) on any web request and returns a slightly modified instance.
Because every request goes through these sequence of plugs, it's a great place to set up authentication, and possibly avoid any requests to pass through if not authenticated.

## Create an authentication plug

You can build your own module plug that gets the _conn_, verifies for authentication with `Plug.BasicAuth`, and then returns the transformed _conn_.

```elixir
defmodule MyWebApp.Plugs.SiteBasicAuth do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn, username: "admin", password: "protected123")
  end
end
```

This is as easy as it could be. Let's break it down:
- We've created a module plug
- A plug always needs a `init` and a `call` definition
- We don't want to do anything on initialization, so we just make `init` a passthrough function
- On `call`, we let the `Plug.BasicAuth.basic_auth` do it's thing, which means it will check for existing authentication and otherwise popup a prompt to authenticate. It will return the (transformed) `conn`, so nothing we need to do there ourselves

## Use the plug in your router

To use the plug we just created, we have to implement it in our router file, so it will be invoked on each request.
If you want to add this authentication to any part of your app, add it to the pipeline of the scope that covers your Beacon app:

```elixir
scope "/" do
  pipe_through [:browser, MyWebApp.Plugs.SiteBasicAuth]
  beacon_site "/", site: :my_site
end
```

And that's it! Run your app and go to any page. It should popup a username and password prompt in order to see your app.

# Specific pages authentication

The previous example protects your whole app. In some cases you might only want to protect a few specific pages of your app.
As Beacon is handling all routing of a scope, we cannot just add a router's scope to cover this, because it will always go through the default scope where you define the `beacon_site` as a "catch-all". 
You can change your existing plug (or create a separate one) to do a check on what page is being requested (we're using `conn.request_path`).
For hardcoded paths, we can use a guard to only match when it's one of your protected pages, and keep a fallback / default `call` definition for all the other pages that shouldn't do anything.


```elixir
defmodule MyWebApp.Plugs.ProtectedPages do
  @moduledoc false
  @behaviour Plug

  @protected_pages [
    "/your/protected/page",
    "/another/secret"
  ]

  def init(opts), do: opts

  def call(conn, _opts) when conn.request_path in @protected_pages do
    Plug.BasicAuth.basic_auth(conn, username: "admin", password: "protected123")
  end

  def call(conn, _opts), do: conn
end
```

Note: this example is just for easy hardcoded authentication. For more advanced authentication you could extend this approach in many ways, for example by setting an environment variable for the username and password, or even setting up a database with users.
Same for the protected pages which could be stored somewhere else, or might be more dynamic or having a more complicated check on what the path looks like.
