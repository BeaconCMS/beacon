defmodule Beacon.BeaconTest.NoRoutesRouter do
  use Beacon.BeaconTest.Web, :router
end

defmodule Beacon.BeaconTest.ReachTestRouter do
  use Beacon.BeaconTest.Web, :router
  use Beacon.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope path: "/host_test", host: "host.com" do
    pipe_through :browser
    beacon_site "/", site: :host_test
  end

  scope path: "/conflict" do
    pipe_through :browser
    live "/:page", Beacon.BeaconTest.LiveViews.FooBarLive
    beacon_site "/", site: :not_booted
  end

  scope path: "/my_site" do
    pipe_through :browser
    beacon_site "/", site: :my_site
  end

  scope path: "/other" do
    pipe_through :browser
  end
end

defmodule Beacon.BeaconTest.Router do
  use Beacon.BeaconTest.Web, :router
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

  # `alias` is not really used but is present here to verify that `beacon_site` has no conflicts with custom aliases
  scope path: "/", alias: AnyAlias do
    pipe_through :browser
    beacon_site "/other", site: :not_booted
    beacon_site "/", site: :my_site
  end
end
