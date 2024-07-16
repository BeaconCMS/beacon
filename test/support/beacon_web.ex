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
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import PhoenixHTMLHelpers.Form, except: [label: 1]
      import PhoenixHTMLHelpers.Link
      import PhoenixHTMLHelpers.Tag
      import PhoenixHTMLHelpers.Format
      import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3]
      import BeaconWeb, only: [assign: 2, assign: 3, assign_new: 3]
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
