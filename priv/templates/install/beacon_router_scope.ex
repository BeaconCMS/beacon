
  scope "/", BeaconWeb do
    pipeline :beacon do
      plug BeaconWeb.Plug
    end

    pipe_through :browser
    pipe_through :beacon

    live_session :beacon, session: %{"beacon_site" => "<%= beacon_site %>"} do
      live "/beacon/*path", PageLive, :path
    end
  end
end
