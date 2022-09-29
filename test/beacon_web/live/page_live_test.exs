defmodule BeaconWeb.Live.PageLiveTest do
  use Beacon.DataCase, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Beacon.Pages
  alias Beacon.Layouts
  alias Beacon.Components
  alias Beacon.Stylesheets

  defp create_page do
    Stylesheets.create_stylesheet!(%{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })

    Components.create_component!(%{
      site: "my_site",
      name: "sample_component",
      body: ~S"""
      <li id={"my-component-#{@val}"}>
        <%= @val %>
      </li>
      """
    })

    layout =
      Layouts.create_layout!(%{
        site: "my_site",
        title: "Sample Home Page",
        meta_tags: %{"foo" => "bar"},
        stylesheet_urls: [],
        body: """
        <header>Page header</header>
        <%= @inner_content %>
        <footer>Page footer</footer>
        """
      })

    page =
      Pages.create_page!(%{
        path: "home",
        site: "my_site",
        layout_id: layout.id,
        template: """
        <main>
          <h2>Some Values:</h2>
          <ul>
            <%= for val <- @beacon_live_data[:vals] do %>
              <%= my_component("sample_component", val: val) %>
            <% end %>
          </ul>

          <.form let={f} for={:greeting} phx-submit="hello">
            Name: <%= text_input f, :name %>
            <%= submit "Hello" %>
          </.form>

          <%= if assigns[:message], do: assigns.message %>
        </main>
        """
      })

    Pages.create_page_event!(%{
      page_id: page.id,
      event_name: "hello",
      code: """
        {:noreply, Phoenix.Component.assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
      """
    })

    # Make sure events are loaded.
    Beacon.Loader.DBLoader.load_from_db()
  end

  # Dummy APP setup.
  @config [
    debug_errors: false,
    render_errors: [view: DummyApp.ErrorView],
    root: Path.expand("..", __DIR__),
    secret_key_base: "dVxFbSNspBVvkHPN5m6FE6iqNtMnhrmPNw7mO57CJ6beUADllH0ux3nhAI1ic65X",
    url: [host: "localhost"],
    live_view: [signing_salt: "ykjYicLHN3EuW0FO"],
    url: [host: "test-app.com"],
    http: [port: 4000],
    server: true
  ]

  Application.put_env(:beacon, DummyApp.Endpoint, @config)

  @endpoint DummyApp.Endpoint

  setup_all do
    start_supervised!(@endpoint)
    on_exit(fn -> Application.delete_env(:beacon, :serve_endpoints) end)
    :ok
  end

  test "render the given path" do
    create_page()

    {:ok, view, html} = live(Phoenix.ConnTest.build_conn(), "/home")

    assert html =~ "body {cursor: zoom-in;}"
    assert html =~ "<header>Page header</header>"
    assert html =~ ~s"<main><h2>Some Values:</h2>"
    assert html =~ ~s(<li id="my-component-first">)
    assert html =~ ~s(<li id="my-component-second">)
    assert html =~ ~s(<li id="my-component-third">)
    assert html =~ "<footer>Page footer</footer>"

    assert view
           |> element("form")
           |> render_submit(%{greeting: %{name: "Beacon"}}) =~ "Hello Beacon"
  end

  test "when the given path doesn't exist" do
    create_page()

    error_message = """
    Could not call layout_id_for_path for the given path: [\"no_page_match\"].

    Make sure you have created a page for this path. Check Pages.create_page!/2 \
    for more info.\
    """

    assert_raise Beacon.Loader.Error, error_message, fn ->
      {:ok, _view, _html} = live(Phoenix.ConnTest.build_conn(), "/no_page_match")
    end
  end
end
