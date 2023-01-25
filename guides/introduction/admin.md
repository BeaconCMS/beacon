## Admin UI

In that interface you'll be able to manage versioned pages and access more features as they are added to Beacon.

1. Edit the file `router.ex` in your project to look like:

```elixir
import Beacon.Router

scope "/" do
  pipe_through :browser
  beacon_admin "/admin"
end
```

2. Visit <http://localhost:4000/admin>

### Protecting the Admin UI

In production environments it's a good idea to add some sort of protection to block admin from unauthorized access. Following is an example using [Plug.BasicAuth](https://hexdocs.pm/plug/1.14.0/Plug.BasicAuth.html) to get started if your application doesn't have a protected admin scope already.

```elixir
pipeline :admin_protected do
  plug :admin_basic_auth
end

scope "/admin" do
  pipe_through [:browser, :admin_protected]
  beacon_admin "/"
end

defp admin_basic_auth(conn, _opts) do
  username = System.fetch_env!("ADMIN_AUTH_USERNAME")
  password = System.fetch_env!("ADMIN_AUTH_PASSWORD")
  Plug.BasicAuth.basic_auth(conn, username: username, password: password)
end
```
