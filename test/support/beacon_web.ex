defmodule Beacon.BeaconWebTest do
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
      use Phoenix.View, root: "test/templates"

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      use PhoenixHTMLHelpers
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Phoenix.Component
      import Phoenix.View

      alias Beacon.BeaconTest.Router.Helpers, as: Routes
    end
  end
end

defmodule Beacon.BeaconTest.LayoutView do
  use Beacon.BeaconWebTest, :view
end

defmodule Beacon.BeaconTest.ErrorView do
  use Beacon.BeaconWebTest, :view

  def render(_template, _assigns), do: "Error"
end
