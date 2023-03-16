## API

HTTP endpoints to integrate with Beacon layouts, pages, assets, and more.

1. Edit the file `router.ex` in your project to add:

```elixir
use Beacon.Router

scope "/api"
  pipe_through :api
  beacon_api "/beacon"
end
```

Check out `/lib/beacon/router.ex` for currently available API endpoints.
