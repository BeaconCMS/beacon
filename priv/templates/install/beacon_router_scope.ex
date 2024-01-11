
  use Beacon.Router

  scope "/" do
    pipe_through :browser
    beacon_site "<%= path %>", site: :<%= site %>
  end
