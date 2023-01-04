defmodule Beacon.BeaconTest.Router do
  use Beacon.BeaconTest, :router

  require BeaconWeb.Admin

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Beacon.BeaconTest.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :beacon do
    plug BeaconWeb.Plug
  end

  scope "/admin", BeaconWeb.Admin do
    pipe_through :browser

    BeaconWeb.Admin.routes()
  end

  scope "/", BeaconWeb do
    pipe_through :browser
    pipe_through :beacon

    live_session :beacon, session: %{"beacon_site" => "my_site"} do
      live "/*path", PageLive, :path
    end
  end
end
