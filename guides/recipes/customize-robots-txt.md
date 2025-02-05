# Customize robots.txt

By default, Beacon will serve a simple, permissive `robots.txt` for each site, which allows all crawlers full access.  This can be customized by adding rules to your Beacon Config:

```
config :my_app, Beacon,
  site: :site_a,
  ...,
  robots: [
    [user_agent: "*", disallow: ["/priv/path", "/other/path"]],
    [user_agent: ["SomeBot", "OtherBot"], disallow: "/"]
  ]
```

## Disallowing Crawlers from Admin Dashboard

If you use an Admin dashboard (such as [BeaconLiveAdmin](https://hexdocs.pm/beacon_live_admin/installation.html)) then it's common to add a disallow rule for that route.  For example, if our router has the following routes:

```
scope "/" do
  ...
  beacon_live_admin "/admin"

  beacon_site "/", site: :my_site
end
```

then a rule should be added to the Beacon Config:

```
config :my_app, Beacon,
  site: :my_site,
  ...,
  robots: [
    ...
    [user_agent: "*", disallow: "/admin"]
  ]
```

## Multiple Sites on the Same Host

If you're serving multiple Beacon sites at the same host domain, it's expected for your robots.txt to have the same rules in each of those sites.  For example:

```
scope "/", host: "home.com" do
  beacon_site "/blog", site: :blog
  beacon_site "/catalog", site: :catalog
end

scope "/", host: "another.com" do
  beacon_site "/", site: :another
end
```

When defining your Beacon Config, first assign the robots.txt rules to a variable, then call it from each of those sites which share a host:

```
home_robots = [
  [user_agent: "*", disallow: ["/admin", "/catalog/private"]]
]

config :beacon, :blog,
  ...
  robots: home_robots

config :beacon, :catalog,
  ...
  robots: home_robots

config :beacon, :another,
  ...
  robots: # something else
```