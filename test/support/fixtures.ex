defmodule Beacon.Fixtures do
  @moduledoc false

  # Test data
  #
  # Each fixture call `Beacon.Loader.reload_*` to simulate PROD environment
  # where a pubsub event is broadcasted to reload the module asyncly,
  # so here we reload such modules eagerly.

  alias Beacon.Content
  alias Beacon.Content.ErrorPage
  alias Beacon.Content.PageEventHandler
  alias Beacon.Content.PageVariant
  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.UploadMetadata
  alias Beacon.Repo

  defp get_lazy(attrs, key, fun) when is_map(attrs), do: Map.get_lazy(attrs, key, fun)
  defp get_lazy(attrs, key, fun), do: Keyword.get_lazy(attrs, key, fun)

  def stylesheet_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })
    |> Content.create_stylesheet!()
    |> tap(fn stylesheet -> Beacon.Loader.reload_stylesheet_module(stylesheet.site) end)
  end

  def component_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "sample_component",
      body: ~S"""
      <span id={"my-component-#{@val}"}><%= @val %></span>
      """,
      category: "other"
    })
    |> Content.create_component!()
    |> tap(fn component -> Beacon.Loader.reload_components_module(component.site) end)
  end

  def layout_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      title: "Sample Home Page",
      meta_tags: [],
      resource_links: [],
      template: """
      <header>Page header</header>
      <%= @inner_content %>
      <footer>Page footer</footer>
      """
    })
    |> Content.create_layout!()
  end

  def published_layout_fixture(attrs \\ %{}) do
    {:ok, layout} =
      attrs
      |> layout_fixture()
      |> Content.publish_layout()
      |> tap(fn {:ok, layout} -> Beacon.Loader.reload_layout_module(layout.site, layout.id) end)

    layout
  end

  def page_fixture(attrs \\ %{}) do
    layout_id = get_lazy(attrs, :layout_id, fn -> layout_fixture().id end)

    attrs
    |> Enum.into(%{
      site: "my_site",
      layout_id: layout_id,
      path: "/home",
      title: "home",
      meta_tags: [],
      template: """
      <main>
        <h1>my_site#home</h1>
      </main>
      """,
      format: :heex
    })
    |> Content.create_page!()
  end

  def published_page_fixture(attrs \\ %{}) do
    {:ok, page} =
      attrs
      |> page_fixture()
      |> Content.publish_page()
      |> tap(fn {:ok, page} -> Beacon.Loader.reload_page_module(page.site, page.id) end)

    page
  end

  def page_helper_params(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "upcase",
      args: "%{name: name}",
      code: """
      String.upcase(name)
      """
    })
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
      """
    })
    |> Content.create_snippet_helper!()
    |> tap(fn snippet -> Beacon.Loader.reload_snippets_module(snippet.site) end)
  end

  def media_library_asset_fixture(attrs \\ %{}) do
    attrs
    |> upload_metadata_fixture()
    |> MediaLibrary.upload()
  end

  def upload_metadata_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        site: :my_site,
        file_size: 100_000,
        extra: %{"alt" => "some alt text"}
      })
      |> Map.put_new(:file_name, "image.jpg")

    attrs = Map.put_new(attrs, :file_path, path_for(attrs.file_name))

    UploadMetadata.new(attrs.site, attrs.file_path, name: attrs.file_name, size: attrs.file_size, extra: attrs.extra)
  end

  defp path_for(file_name) do
    ext = Path.extname(file_name)
    file_name = "image#{ext}"

    Path.join(["test", "support", "fixtures", file_name])
  end

  def page_variant_fixture(attrs \\ %{})

  def page_variant_fixture(%{page: %Content.Page{} = page} = attrs), do: page_variant_fixture(page, attrs)

  def page_variant_fixture(%{page_id: page_id} = attrs) do
    page_id
    |> Content.get_page!()
    |> page_variant_fixture(attrs)
  end

  defp page_variant_fixture(page, attrs) do
    full_attrs = %{
      name: attrs[:name] || "Variant #{System.unique_integer([:positive])}",
      weight: attrs[:weight] || Enum.random(1..10),
      template: attrs[:template] || template_for(page)
    }

    page
    |> Ecto.build_assoc(:variants)
    |> PageVariant.changeset(full_attrs)
    |> Repo.insert!()
  end

  defp template_for(%{format: :heex} = _page), do: "<div>My Site</div>"
  defp template_for(%{format: :markdown} = _page), do: "# My site"

  def page_event_handler_fixture(attrs \\ %{})

  def page_event_handler_fixture(%{page: %Content.Page{} = page} = attrs),
    do: page_event_handler_fixture(page, attrs)

  def page_event_handler_fixture(%{page_id: page_id} = attrs) do
    page_id
    |> Content.get_page!()
    |> page_event_handler_fixture(attrs)
  end

  defp page_event_handler_fixture(page, attrs) do
    full_attrs = %{
      name: attrs[:name] || "Event Handler #{System.unique_integer([:positive])}",
      code: attrs[:code] || "{:noreply, socket}"
    }

    page
    |> Ecto.build_assoc(:event_handlers)
    |> PageEventHandler.changeset(full_attrs)
    |> Repo.insert!()
  end

  def error_page_fixture(attrs \\ %{}) do
    layout = get_lazy(attrs, :layout, fn -> layout_fixture() end)

    attrs
    |> Enum.into(%{
      site: "my_site",
      status: Enum.random(ErrorPage.valid_statuses()),
      template: "Uh-oh!",
      layout_id: layout.id
    })
    |> Content.create_error_page!()
    |> tap(fn error_page -> Beacon.Loader.reload_error_page_module(error_page.site) end)
  end

  def live_data_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      path: "/foo/bar"
    })
    |> Content.create_live_data!()
  end

  def live_data_assign_fixture(attrs \\ %{}) do
    live_data = get_lazy(attrs, :live_data, fn -> live_data_fixture() end)
    site = live_data.site

    attrs =
      Enum.into(attrs, %{
        key: "bar",
        value: "Hello world!",
        format: :text
      })

    live_data =
      live_data
      |> Ecto.build_assoc(:assigns)
      |> Content.LiveDataAssign.changeset(attrs)
      |> Repo.insert!()

    Beacon.Loader.reload_live_data_module(site)

    live_data
  end
end
