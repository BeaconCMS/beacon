# Multiple Domains/Tenants

You can host multiple domains or subdomains with Phoenix by using the `:host` option of the scope function in your router:

`:host` - a string or list of strings containing the host scope, or prefix host scope (e.g. `"foo.bar.com"`, `"foo."`)

```elixir
# match `admin.` subdomain
scope "/", MyAppWeb, host: "admin." do
  live "/", AdminLive, :new
end

# match `example.com` and `example2.com`
scope "/", MyAppWeb, host: ["example.com", "example2.com"] do
  live "/", LandingLive, :new
end

# match only `my-example.org`
scope "/", MyAppWeb, host: "my-example.org" do
  live "/", HomeLive, :new
end
```

## Multiple Domains/Tenants hosting with BeaconCMS

If you need to host multiple domains or subdomains with Beacon, you can still use the same `:host` option described above!

Here's another example, but now using Beacon:

```elixir
# serve the `:demo` site at demo.org/demo
scope "/", host: "demo.org" do
  pipe_through :browser

  beacon_site "/demo", site: :demo
end

# serve the `:blog` site at blog.com
scope "/", host: "blog.com" do
  pipe_through :browser

  beacon_site "/", site: :blog
end

# serve the admin interface at the prefix /admin on the root domain
scope "/admin" do
  pipe_through :browser
  beacon_live_admin "/"
end
```

You also need to pass the `:check_origin` option when configuring your endpoint, in order to explicitly outline which origins are allowed.

In `config/runtime.exs` edit the following config to include your domains:

```elixir
config :my_app, MyAppWeb.Endpoint,
  # ...
  check_origin: [
    "https://beacon-demo.com/",
    "https://demo.org",
    "https://blog.com"
  ]
```

Check out the [Deployment Topologies](https://hexdocs.pm/beacon/deployment-topologies.html) guide for more information.
