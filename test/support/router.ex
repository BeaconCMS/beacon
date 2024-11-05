defmodule Beacon.BeaconTest.Router do
  use Beacon.Beacon.WebTest, :router
  use Beacon.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/nested" do
    pipe_through :browser
    beacon_site "/site", site: :booted
    beacon_site "/media", site: :s3_site
  end

  scope "/" do
    pipe_through :browser
    beacon_site "/other", site: :not_booted
    beacon_site "/", site: :my_site
  end
end
