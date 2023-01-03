defmodule Beacon.Fixtures do
  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Pages
  alias Beacon.Stylesheets

  def get_lazy(attrs, key, fun) when is_map(attrs), do: Map.get_lazy(attrs, key, fun)
  def get_lazy(attrs, key, fun), do: Keyword.get_lazy(attrs, key, fun)

  def stylesheet_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })
    |> Stylesheets.create_stylesheet!()
  end

  def component_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      site: "my_site",
      name: "sample_component",
      body: ~S"""
      <span id={"my-component-#{@val}"}><%= @val %></span>
      """
    })
    |> Components.create_component!()
  end

  def layout_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
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
    |> Layouts.create_layout!()
  end

  def page_fixture(attrs \\ %{}) do
    layout_id = get_lazy(attrs, :layout_id, fn -> layout_fixture().id end)

    Enum.into(
      attrs,
      %{
        path: "home",
        site: "my_site",
        layout_id: layout_id,
        template: """
        <main>
          <h1>my_site#home</h1>
        </main>
        """
      }
    )
    |> Pages.create_page!()
  end

  def page_event_fixture(attrs \\ %{}) do
    page_id = get_lazy(attrs, :page_id, fn -> page_fixture().id end)

    Enum.into(attrs, %{
      page_id: page_id,
      event_name: "hello",
      code: """
        {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
      """
    })
    |> Pages.create_page_event!()
  end

  def page_helper_fixture(attrs \\ %{}) do
    page_id = get_lazy(attrs, :page_id, fn -> page_fixture().id end)

    Enum.into(attrs, %{
      page_id: page_id,
      helper_name: "upcase",
      helper_args: "%{name: name}",
      code: """
        String.upcase(name)
      """
    })
    |> Pages.create_page_helper!()
  end
end
