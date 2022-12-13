defmodule DummyAppWeb.Router do
  use DummyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {DummyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :beacon do
    plug BeaconWeb.Plug
  end

  scope "/", DummyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", BeaconWeb do
    pipe_through :browser
    pipe_through :beacon

    live_session :beacon, session: %{"beacon_site" => "my_site"} do
      live "/beacon/*path", PageLive, :path
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", DummyAppWeb do
  #   pipe_through :api
  # end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:dummy_app, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
