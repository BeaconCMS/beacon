defmodule BeaconWeb do
  @non_assignables [:beacon]

  @doc """
  Same as `Phoenix.Component.assign/2` but raises an error if the key is a reserved assign by Beacon.
  """
  def assign(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.each(keyword_or_map, fn {key, _value} ->
      validate_assign_key!(key)
    end)

    Phoenix.Component.assign(socket_or_assigns, keyword_or_map)
  end

  @doc """
  Same as `Phoenix.Component.assign/3` but raises an error if the `key` is a reserved assign by Beacon.
  """
  def assign(socket_or_assigns, key, value) do
    validate_assign_key!(key)
    Phoenix.Component.assign(socket_or_assigns, key, value)
  end

  @doc """
  Same as `Phoenix.Component.assign_new/3` but raises an error if the `key` is a reserved assign by Beacon.
  """
  def assign_new(socket_or_assigns, key, fun) do
    validate_assign_key!(key)
    Phoenix.Component.assign_new(socket_or_assigns, key, fun)
  end

  defp validate_assign_key!(assign) when assign in @non_assignables do
    raise ArgumentError, "#{inspect(assign)} is a reserved assign by Beacon and it cannot be set directly"
  end

  # we let LiveView perform the other validations
  defp validate_assign_key!(_key), do: :ok

  @doc false
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

  @doc false
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BeaconWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @doc false
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc false
  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  @doc false
  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import PhoenixHTMLHelpers.Form, except: [label: 1]
      import PhoenixHTMLHelpers.Link
      import PhoenixHTMLHelpers.Tag
      import PhoenixHTMLHelpers.Format
      alias Phoenix.LiveView.JS
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
