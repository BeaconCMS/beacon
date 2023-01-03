defmodule Beacon.Fixtures do
  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Pages
  alias Beacon.Stylesheets

  def stylesheet_fixture(attrs \\ %{}) do
    %{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    }
    |> Map.merge(attrs)
    |> Stylesheets.create_stylesheet!()
  end

  def component_fixture(attrs \\ %{}) do
    %{
      site: "my_site",
      name: "sample_component",
      body: ~S"""
      <span id={"my-component-#{@val}"}><%= @val %></span>
      """
    }
    |> Map.merge(attrs)
    |> Components.create_component!()
  end

  def layout_fixture(attrs \\ %{}) do
    %{
      site: "my_site",
      title: "Sample Home Page",
      meta_tags: %{"foo" => "bar"},
      stylesheet_urls: [],
      body: """
      <header>Page header</header>
      <%= @inner_content %>
      <footer>Page footer</footer>
      """
    }
    |> Map.merge(attrs)
    |> Layouts.create_layout!()
  end

  def page_fixture(attrs \\ %{}) do
    layout_id = Map.get_lazy(attrs, :layout_id, fn -> layout_fixture().id end)

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
    |> Map.merge(attrs)
    |> Pages.create_page!()
  end

  def page_event_fixture(attrs \\ %{}) do
    page_id = Map.get_lazy(attrs, :page_id, fn -> page_fixture().id end)

    %{
      page_id: page_id,
      event_name: "hello",
      code: """
        {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
      """
    }
    |> Map.merge(attrs)
    |> Pages.create_page_event!()
  end

  def page_helper_fixture(attrs \\ %{}) do
    page_id = Map.get_lazy(attrs, :page_id, fn -> page_fixture().id end)

    %{
      page_id: page_id,
      helper_name: "upcase",
      helper_args: "%{name: name}",
      code: """
        String.upcase(name)
      """
    }
    |> Map.merge(attrs)
    |> Pages.create_page_helper!()
  end
end
