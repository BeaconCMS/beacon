# Customize robots.txt

By default, Phoenix provides a single `robots.txt` file for your application, located in your `/priv/static` folder and served by `Plug.Static` in the Endpoint.  A Beacon app can continue to use this strategy if all sites are hosted at the same domain.  However, if your app has several sites with separate hosts, you'll want to provide a separate `robots.txt` for each one.  Beacon provides this feature, but you must first disable the default Phoenix functionality.

First go to `/lib/my_app_web/endpoint.ex` and find `Plug.Static`:

```
plug Plug.Static,
  at: "/",
  from: :my_app,
  gzip: false,
  only: MyAppWeb.static_paths()
```

If your Plug looks like above, go to `/lib/my_app_web.ex` and find `static_paths/0`:

```
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
```

Remove `robots.txt` to disable Phoenix's default.

If your `Plug.Static` looks different, e.g.:

```
plug Plug.Static,
    at: "/",
    from: :my_app_web,
    only: ~w(assets css fonts images js favicon.ico robots.txt)
```

just remove `robots.txt` here and you're done!

With Phoenix no longer serving `robots.txt`, Beacon will now serve its own default for each site, which is allows all crawlers full access.  This can be customized by adding rules to your Beacon Config:

```
config :my_app, Beacon,
  site: :site_a,
  ...,
  robots: [
    [user_agent: "*", disallow: ["/priv/path", "/other/path"]],
    [user_agent: ["SomeBot", "OtherBot"], disallow: "/"]
  ]
```