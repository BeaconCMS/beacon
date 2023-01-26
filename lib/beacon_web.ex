defmodule BeaconWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use BeaconWeb, :controller
      use BeaconWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller,
        namespace: BeaconWeb,
        formats: [:html, :json],
        layouts: [html: BeaconWeb.Layouts]

      import Plug.Conn
      import BeaconWeb.Gettext
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BeaconWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import BeaconWeb.CoreComponents
      import BeaconWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Router helpers
      alias BeaconWeb.Router.Helpers, as: Routes

      # Admin Router helper
      import Beacon.Router, only: [beacon_admin_path: 2, beacon_admin_path: 3]
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
