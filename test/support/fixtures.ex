defmodule Beacon.Fixtures do
  alias Beacon.Admin.MediaLibrary
  alias Beacon.Components
  alias Beacon.Layouts
  alias Beacon.Pages
  alias Beacon.Stylesheets

  def get_lazy(attrs, key, fun) when is_map(attrs), do: Map.get_lazy(attrs, key, fun)
  def get_lazy(attrs, key, fun), do: Keyword.get_lazy(attrs, key, fun)

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
      meta_tags: [
        %{"content" => "value", "name" => "layout-meta-tag-one"},
        %{"name" => "layout-meta-tag-two", "content" => "value"}
      ],
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
      meta_tags: [
        %{"content" => "value", "name" => "home-meta-tag-one"},
        %{"name" => "home-meta-tag-two", "content" => "value"},
        %{"name" => "csrf-token", "content" => "value"}
      ],
      template: """
      <main>
        <h1>my_site#home</h1>
      </main>
      """
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
      """
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
      """
    })
    |> Pages.create_page_helper!()
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

  @layout_meta_tag_one ~s(<meta name="layout-meta-tag-one" content="value"/>)
  @layout_meta_tag_two ~s(<meta name="layout-meta-tag-two" content="value"/>)
  @home_meta_tag_one ~s(<meta name="home-meta-tag-one" content="value"/>)
  @home_meta_tag_two ~s(<meta name="home-meta-tag-two" content="value"/>)
  @charset ~s(<meta charset="utf-8"/>)
  @http_equiv ~s(<meta http-equiv="X-UA-Compatible" content="IE=edge"/>)
  @viewport ~s(<meta name="viewport" content="width=device-width, initial-scale=1"/>)
  @csrf_token ~r(<meta name=\"csrf-token\" content=\".+\"\/>)

  def meta_tag_fixture do
    %{
      "layout-meta-tag-one" => @layout_meta_tag_one,
      "layout-meta-tag-two" => @layout_meta_tag_two,
      "home-meta-tag-one" => @home_meta_tag_one,
      "home-meta-tag-two" => @home_meta_tag_two,
      "csrf-token" => @csrf_token,
      "correct_order" =>
        @home_meta_tag_one <>
          @home_meta_tag_two <>
          @layout_meta_tag_one <>
          @layout_meta_tag_two <>
          @charset <>
          @http_equiv <>
          @viewport
    }
  end
end
