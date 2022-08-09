defmodule DummyApp.Router do
  use DummyApp, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {DummyApp.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :beacon do
    plug(BeaconWeb.Plug)
  end

  scope "/", BeaconWeb do
    pipe_through(:browser)
    pipe_through(:beacon)

    live_session :beacon, session: %{"beacon_site" => "my_site"} do
      live("/*path", PageLive, :path)
    end
  end
end
