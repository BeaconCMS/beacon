defmodule Beacon.BeaconTest.Router do
  use Beacon.BeaconTest, :router
  use Beacon.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug BeaconWeb.API.Plug
  end

  scope "/api" do
    pipe_through :api
    beacon_api "/"
  end

  scope "/" do
    pipe_through :browser
    beacon_site "/", site: :my_site
  end
end
