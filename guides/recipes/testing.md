# Testing

Integrating your app with Beacon might require testing some parts of that integration,
so in this recipe let's suppose you have added a hook in the publish page lifecycle as described in the [Notify Page Published](notify-page-published.md) recipe,
and now you want to make sure the email is being sent when a page is published, as it was defined in the hook.

## Config

First you should enable the `:testing` mode for each site you want to test:

Assuming your site configuration looks like:

```elixir
@impl Application
def start(_type, _args) do
  children = [
    # ... omitted for brevity
    {Beacon, sites: [Application.fetch_env!(:my_app, :my_site)]}
  ]
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Then open the file `config/test.exs` and add the following config to change the Beacon mode:

```elixir
# config/test.exs
config :my_app, :my_site, mode: :testing
```

## Test

And the actual test would look like the example below.

First we create and publish a page by calling the [fixture](https://hexdocs.pm/beacon/0.1.0-rc.2/Beacon.Test.Fixtures.html) `beacon_published_page_fixture/0`,
then we build and assert the correct email was delivered, using [assert_delivered_email/1](https://hexdocs.pm/bamboo/Bamboo.Test.html#assert_delivered_email/2)
from the Bamboo library.

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
```