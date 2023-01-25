## Admin UI

In that interface you'll be able to manage versioned pages and access more features as they are added to Beacon.

1. Edit the file `router.ex` in your project to add:

```elixir
import Beacon.Router

scope "/beacon" do
  pipe_through :browser
  beacon_admin "/admin"
end
```

2. Visit <http://localhost:4000/beacon/admin>
