# Reuse app.css

Your Phoenix application has a `app.css` that you might want to use to generate styles for your site,
and in this guide we'll see how to configure your site and make the neceeary changes to deploy your app.

In your site config, usually located at `runtime.exs`, you should add a new config `:tailwind_css`
to let Beacon know where to find the `app.css` file:

```elixir
tailwind_css =
  if config_env() == :prod do
    Path.expand("../../app.css", __DIR__)
  else
    Path.expand("../assets/css/app.css", __DIR__)
  end

config :beacon,
  my_site: [
    site: :my_site,
    repo: MyApp.Repo,
    endpoint: MyAppWeb.Endpoint,
    router: MyAppWeb.Router,
    tailwind_css: tailwind_css
  ]
```

Note the path is different for developments and production environments.
See the recipe [Deploy to Fly.io](deploy-to-flyio.md) for more info on how to deploy your app.