## API

HTTP endpoints to integrate with Beacon layouts, pages, assets, and more.

1. Edit the file `router.ex` in your project to add:

```elixir
use Beacon.Router

scope "/api" do
  pipe_through :api
  plug BeaconWeb.API.Plug
  beacon_api "/beacon"
end
```

The `plug BeaconWeb.API.Plug` is needed only if the client consuming this API wants to send or receive camelCased json keys.

Check out `/lib/beacon/router.ex` for currently available API endpoints.
