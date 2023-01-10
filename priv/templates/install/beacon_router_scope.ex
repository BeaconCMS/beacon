
  scope "/", BeaconWeb do
    pipe_through :browser
    pipe_through :beacon

    live_session :beacon, session: %{"beacon_site" => "<%= beacon_site %>"} do
      live "/beacon/*path", PageLive, :path
    end
  end
end
