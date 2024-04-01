defmodule BeaconWeb do
  @moduledoc false

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
      # HTML helpers and components
      use PhoenixHTMLHelpers
      import Phoenix.HTML
      import Phoenix.HTML.Form

      # Core UI components and translation
      import BeaconWeb.CoreComponents
      import BeaconWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Router helpers
      alias BeaconWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
