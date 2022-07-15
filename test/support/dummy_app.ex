defmodule DummyApp do
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/dummy_app/templates", namespace: DummyApp

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      use Phoenix.HTML

      import Phoenix.LiveView.Helpers
      import Phoenix.View

      alias DummyApp.Router.Helpers, as: Routes
    end
  end
end

defmodule DummyApp.LayoutView do
  use DummyApp, :view
end

defmodule DummyApp.ErrorView do
  use DummyApp, :view

  def render(_template, _assigns), do: "Error"
end

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

defmodule DummyApp.Endpoint do
  # The otp app needs to be beacon otherwise Phoenix LiveView will not be
  # able to build the static path since it tries to get from `Application.app_dir`
  # which expects that a real "application" is settled.
  use Phoenix.Endpoint, otp_app: :beacon

  @session_options [store: :cookie, key: "_dummy_app_key", signing_salt: "secret"]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Session, store: :cookie, key: "_app_key", signing_salt: "5Ude+fet")

  plug(DummyApp.Router)
end

defmodule DummyApp.BeaconDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data("my_site", ["home"], _params), do: %{vals: ["first", "second", "third"]}
  def live_data(_, _, _), do: %{}
end
