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

  scope "/" do
    pipe_through :browser
    beacon_sitemap_index "/sitemap_index.xml"
  end

  scope "/nested" do
    pipe_through :browser
    beacon_site "/site", site: :booted
    beacon_site "/media", site: :s3_site
  end

  scope "/" do
    pipe_through :browser

    live_session :default do
      live "/", Beacon.BeaconTest.LiveViews.FooBarLive
      live "/nested/:page", Beacon.BeaconTest.LiveViews.FooBarLive
    end
  end

  scope path: "/", host: "host.com" do
    pipe_through :browser
    beacon_site "/", site: :host_test
  end

  # `alias` is not really used but is present here to verify that `beacon_site` has no conflicts with custom aliases
  scope path: "/", alias: AnyAlias do
    pipe_through :browser

    beacon_site "/other", site: :not_booted
    beacon_site "/", site: :my_site
  end
end
