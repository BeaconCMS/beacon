defmodule Beacon.Fixtures do
  alias Beacon.Content
  alias Beacon.Content.PageVariant
  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.UploadMetadata
  alias Beacon.Repo

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
    |> Content.create_stylesheet!()
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
    |> Content.create_component!()
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
    |> Content.create_layout!()
  end

  def published_layout_fixture(attrs \\ %{}) do
    {:ok, layout} =
      attrs
      |> layout_fixture()
      |> Content.publish_layout()

    layout
  end

  def page_fixture(attrs \\ %{}) do
    layout_id = get_lazy(attrs, :layout_id, fn -> layout_fixture().id end)

    attrs
    |> Enum.into(%{
      path: "/home",
      site: "my_site",
      layout_id: layout_id,
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

    page
  end

  def page_event_params(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "hello",
      code: """
        {:noreply, assign(socket, :message, "Hello \#{event_params["greeting"]["name"]}!")}
      """
    })
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
  end

  def media_library_asset_fixture(attrs \\ %{}) do
    attrs
    |> file_metadata_fixture()
    |> MediaLibrary.upload()
  end

  def file_metadata_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        site: :my_site,
        file_size: 100_000
      })
      |> Map.put_new(:file_name, "image.jpg")

    attrs = Map.put_new(attrs, :file_path, path_for(attrs.file_name))

    UploadMetadata.new(attrs.site, attrs.file_path, name: attrs.file_name, size: attrs.file_size)
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
end
