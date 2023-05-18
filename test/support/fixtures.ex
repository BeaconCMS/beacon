defmodule Beacon.Fixtures do
  alias Beacon.Admin.MediaLibrary
  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Pages
  alias Beacon.Snippets
  alias Beacon.Stylesheets

  def get_lazy(attrs, key, fun) when is_map(attrs), do: Map.get_lazy(attrs, key, fun)
  def get_lazy(attrs, key, fun), do: Keyword.get_lazy(attrs, key, fun)

  def conn_admin(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:session_id, "admin_session_123")
  end

  def stylesheet_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })
    |> Stylesheets.create_stylesheet!()
  end

  def component_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "sample_component",
      body: ~S"""
      <span id={"my-component-#{@val}"}><%= @val %></span>
      """
    })
    |> Components.create_component!()
  end

  def layout_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      title: "Sample Home Page",
      meta_tags: [],
      stylesheet_urls: [],
      body: """
      <header>Page header</header>
      <%= @inner_content %>
      <footer>Page footer</footer>
      """
    })
    |> Layouts.create_layout!()
  end

  def layout_without_meta_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      title: "Sample Home Page",
      stylesheet_urls: [],
      body: """
      <header>Page header</header>
      <%= @inner_content %>
      <footer>Page footer</footer>
      """
    })
    |> Layouts.create_layout!()
  end

  def page_fixture(attrs \\ %{}) do
    layout_id = get_lazy(attrs, :layout_id, fn -> layout_fixture().id end)

    attrs
    |> Enum.into(%{
      path: "home",
      site: "my_site",
      layout_id: layout_id,
      meta_tags: [],
      template: """
      <main>
        <h1>my_site#home</h1>
      </main>
      """,
      skip_reload: true,
      status: :published,
      format: :heex
    })
    |> Pages.create_page!()
  end

  def page_without_meta_fixture(attrs \\ %{}) do
    layout_id = get_lazy(attrs, :layout_id, fn -> layout_fixture().id end)

    attrs
    |> Enum.into(%{
      path: "home",
      site: "my_site",
      layout_id: layout_id,
      template: """
      <main>
        <h1>my_site#home</h1>
      </main>
      """
    })
    |> Pages.create_page!()
  end

  def page_event_fixture(attrs \\ %{}) do
    page_id = get_lazy(attrs, :page_id, fn -> page_fixture().id end)

    attrs
    |> Enum.into(%{
      page_id: page_id,
      event_name: "hello",
      code: """
        {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
      """,
      skip_reload: true
    })
    |> Pages.create_page_event!()
  end

  def page_helper_fixture(attrs \\ %{}) do
    page_id = get_lazy(attrs, :page_id, fn -> page_fixture().id end)

    attrs
    |> Enum.into(%{
      page_id: page_id,
      helper_name: "upcase",
      helper_args: "%{name: name}",
      code: """
      String.upcase(name)
      """,
      skip_reload: true
    })
    |> Pages.create_page_helper!()
  end

  def snippet_helper_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "upcase_title",
      body: """
      assigns
      |> get_in(["page", "title"])
      |> String.upcase()
      """,
      skip_reload: true
    })
    |> Snippets.create_helper!()
  end

  def media_library_asset_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        site: "my_site",
        file_path: Path.join(["test", "support", "fixtures", "image.jpg"]),
        file_name: "image.jpg",
        file_type: "image/jpg"
      })

    {:ok, asset} = MediaLibrary.upload(attrs.site, attrs.file_path, attrs.file_name, attrs.file_type)
    asset
  end
end
