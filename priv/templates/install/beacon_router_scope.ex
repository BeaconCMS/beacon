
  use Beacon.Router

  scope "/" do
    pipe_through :browser
    beacon_admin "/admin"
    beacon_site "/<%= site %>", site: :<%= site %>
  end
