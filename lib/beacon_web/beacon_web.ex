defmodule BeaconWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BeaconWeb, :controller
      use BeaconWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: BeaconWeb

      import Plug.Conn
      import BeaconWeb.Gettext
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/beacon_web/templates",
        namespace: BeaconWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BeaconWeb.LayoutView, :live}

      unquote(view_helpers())
    end
  end

  def live_view_dynamic do
    quote do
      use Phoenix.LiveView,
        layout: {BeaconWeb.DynamicLayoutView, :live_dynamic}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import BeaconWeb.Gettext
    end
  end

  # TODO remove phoenix_view after migrating to components
  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView and .heex helpers (live_render, live_patch, <.form>, etc)
      import Phoenix.Component
      import BeaconWeb.CoreComponents

      # Legacy view
      import Phoenix.View

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # import BeaconWeb.Gettext
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
