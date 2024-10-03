# Testing

Integrating your app with Beacon might require testing some parts of that integration,
so in this recipe let's suppose you have added a hook in the publish page lifecycle as described in the [Notify Page Published](notify-page-published.md) recipe,
and now you want to make sure that the email is sent when a page is published.

First you'll need enable the `:testing` mode in your site configuration,
and for this test you'll need to create and publish a page to trigger the hook defined in your site configuration:

## Config

Assuming your site configuration looks like:

```elixir
@impl Application
def start(_type, _args) do
  children = [
    # ... omitted for brevity
    {Beacon, sites: [Application.fetch_env!(:my_app, Beacon)]}
  ]
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Then in the file `config/test.exs` add the following config to change the Beacon mode in the test environment:

```elixir
# config/test.exs
config :my_app, Beacon, mode: :testing
```

## Test

And the actual test would look like the following:

```elixir
defmodule MyApp.CMS.NotificationEmailTest do
  use ExUnit.Case
  use Bamboo.Test
  use Beacon.Test, site: :my_site # <- use this module to enable testing utilities

  test "notify via email when a page is published" do
    page = beacon_published_page_fixture()
    expected_email = MyApp.CMS.notify_email(page)
    assert_delivered_email expected_email
  end
end
````