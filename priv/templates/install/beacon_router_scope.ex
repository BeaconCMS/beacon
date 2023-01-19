
  import Beacon.Router

  scope "/" do
    pipe_through :browser
    beacon_admin "/admin"
    beacon_site "/<%= beacon_site %>", name: "<%= beacon_site %>", data_source: <%= inspect beacon_data_source.module_name %>
  end
