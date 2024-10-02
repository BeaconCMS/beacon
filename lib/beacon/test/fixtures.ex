defmodule Beacon.Test.Fixtures do
  @moduledoc """
  Fixture data for testing Beacon content.

  > #### Only use for testing {: .warning}
  >
  > These fixtures should be used only for testing purposes,
  > if you are looking to run seeds or some sort of content automation
  > then you should use `Beacon.Content` functions instead.
  """

  alias Beacon.Content
  alias Beacon.Content.ErrorPage
  alias Beacon.Content.EventHandler
  alias Beacon.Content.InfoHandler
  alias Beacon.Content.PageVariant
  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.UploadMetadata
  import Beacon.Utils, only: [repo: 1]

  @default_site "my_site"

  defp get(attrs, key) when is_map(attrs), do: Map.get(attrs, key)
  defp get(attrs, key) when is_list(attrs) and is_atom(key), do: Keyword.get(attrs, key)
  defp get(_attrs, _key), do: nil
  defp get_lazy(attrs, key, fun) when is_map(attrs), do: Map.get_lazy(attrs, key, fun)
  defp get_lazy(attrs, key, fun) when is_list(attrs), do: Keyword.get_lazy(attrs, key, fun)

  defp site(attrs) do
    get(attrs, :site) || get(attrs, "site") || @default_site
  end

  def beacon_stylesheet_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: @default_site,
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })
    |> Content.create_stylesheet!()
  end

  @doc """
  Creates a `Beacon.Content.Component`.

  ## Example

      iex> beacon_component_fixture(name: "sample_component")
      %Beacon.Content.Component{}

  """
  def beacon_component_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: @default_site,
      name: "sample_component",
      category: "element",
      attrs: [%{name: "val", type: "any", opts: [required: true]}],
      slots: [],
      body: ~S|assigns = Map.put(assigns, :id, "my-component")|,
      template: ~S|<span id={@id}><%= @val %></span>|,
      example: ~S|<.sample_component val={@val} />|
    })
    |> Content.create_component!()
  end

  def beacon_layout_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: @default_site,
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

  def beacon_published_layout_fixture(attrs \\ %{}) do
    {:ok, layout} =
      attrs
      |> beacon_layout_fixture()
      |> Content.publish_layout()

    layout
  end

  def beacon_page_fixture(attrs \\ %{}) do
    layout_id = get_lazy(attrs, :layout_id, fn -> beacon_layout_fixture().id end)

    attrs
    |> Enum.into(%{
      site: @default_site,
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

  def beacon_published_page_fixture(attrs \\ %{}) do
    site = site(attrs)

    layout_id = get_lazy(attrs, :layout_id, fn -> beacon_published_layout_fixture(site: site).id end)
    attrs = Enum.into(attrs, %{layout_id: layout_id})

    {:ok, page} =
      attrs
      |> beacon_page_fixture()
      |> Content.publish_page()

    page
  end

  @doc false
  def beacon_page_helper_params(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "upcase",
      args: "%{name: name}",
      code: """
      String.upcase(name)
      """
    })
  end

  def beacon_snippet_helper_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: @default_site,
      name: "upcase_title",
      body: """
      assigns
      |> get_in(["page", "title"])
      |> String.upcase()
      """
    })
    |> Content.create_snippet_helper!()
  end

  def beacon_media_library_asset_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    attrs
    |> beacon_upload_metadata_fixture()
    |> MediaLibrary.upload()
  end

  def beacon_upload_metadata_fixture(attrs \\ %{}) do
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

  def beacon_page_variant_fixture(attrs \\ %{})

  def beacon_page_variant_fixture(%{page: %Content.Page{} = page} = attrs), do: beacon_page_variant_fixture(page, attrs)

  def beacon_page_variant_fixture(%{site: site, page_id: page_id} = attrs) do
    site
    |> Content.get_page!(page_id)
    |> beacon_page_variant_fixture(attrs)
  end

  defp beacon_page_variant_fixture(page, attrs) do
    full_attrs = %{
      name: attrs[:name] || "Variant #{System.unique_integer([:positive])}",
      weight: attrs[:weight] || Enum.random(1..10),
      template: attrs[:template] || template_for(page)
    }

    page
    |> Ecto.build_assoc(:variants)
    |> PageVariant.changeset(full_attrs)
    |> repo(page).insert!()
  end

  defp template_for(%{format: :heex} = _page), do: "<div>My Site</div>"
  defp template_for(%{format: :markdown} = _page), do: "# My site"

  def beacon_event_handler_fixture(attrs \\ %{}) do
    full_attrs = %{
      name: attrs[:name] || "Event Handler #{System.unique_integer([:positive])}",
      code: attrs[:code] || "{:noreply, socket}",
      site: attrs[:site] || :my_site
    }

    %EventHandler{}
    |> EventHandler.changeset(full_attrs)
    |> repo(full_attrs.site).insert!()
  end

  def beacon_error_page_fixture(attrs \\ %{}) do
    layout = get_lazy(attrs, :layout, fn -> beacon_layout_fixture() end)

    attrs
    |> Enum.into(%{
      site: @default_site,
      status: Enum.random(ErrorPage.valid_statuses()),
      template: "Uh-oh!",
      layout_id: layout.id
    })
    |> Content.create_error_page!()
  end

  def beacon_live_data_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: @default_site,
      path: "/foo/bar"
    })
    |> Content.create_live_data!()
  end

  def beacon_live_data_assign_fixture(attrs \\ %{}) do
    %{site: site} = live_data = get_lazy(attrs, :live_data, fn -> beacon_live_data_fixture() end)

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
      |> repo(site).insert!()

    live_data
  end

  def beacon_info_handler_fixture(attrs \\ %{}) do
    code = ~S"""
      socket =
        socket
        |> put_flash(
          :info,
          "We just sent an email to your address (#{email})!"
        )

    {:noreply, socket}
    """

    msg = "{:email_sent, email}"

    full_attrs = %{
      site: attrs[:site] || :my_site,
      msg: attrs[:msg] || msg,
      code: attrs[:code] || code
    }

    %InfoHandler{}
    |> InfoHandler.changeset(full_attrs)
    |> repo(full_attrs.site).insert!()
  end
end
