defmodule Beacon.Test.Fixtures do
  @moduledoc """
  Fixture data for testing Beacon content.

  > #### Only use for testing {: .warning}
  >
  > These fixtures should be used only for testing purposes,
  > if you are looking to run seeds or some sort of content automation
  > then you should use `Beacon.Content` functions instead.

  ## Usage

  Most of the times you'll use the `Beacon.Test` function instead of using fixtures directly:

  ```elixir
  use Beacon.Test
  ```

  _Using `Beacon.Test` will import the fixtures for you._

  But you can also use the fixtures directly for some cases:

  ```elixir
  use Beacon.Test.Fixtures
  ```

  ## Default site

  You can pass a default site to be used in the attrs for all fixture functions:

  ```elixir
  use Beacon.Test.Fixtures, site: :blog
  ```

  Note that only one default site is permitted per test module,
  if you have a test that requires asserting multiple sites
  you can just override particular fixtures:

  ```elixir
  use Beacon.Test.Fixtures, site: :blog

  # create a page for the default site
  beacon_page_fixture()

  # create a page for another site
  beacon_page_fixture(site: :other)

  ```

  """

  # FIXME: remove Beacon.Loader dependency in favor of new optimized loader using :error_handler

  alias Beacon.Content
  alias Beacon.Content.ErrorPage
  alias Beacon.Content.EventHandler
  alias Beacon.Content.InfoHandler
  alias Beacon.Content.PageVariant
  alias Beacon.Loader
  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.UploadMetadata
  import Beacon.Utils, only: [repo: 1]

  @doc false
  defmacro __using__(opts) do
    site = Keyword.get(opts, :site, :my_site)

    quote do
      Module.put_attribute(__MODULE__, :__beacon_test_default_site__, unquote(site))
      @before_compile unquote(__MODULE__)
      import Beacon.Test.Fixtures, only: [beacon_page_helper_params: 0, beacon_page_helper_params: 1]
    end
  end

  defmacro __before_compile__(env) do
    site = Module.get_attribute(env.module, :__beacon_test_default_site__)

    quote do
      alias Beacon.Test.Fixtures

      def default_site, do: unquote(Macro.escape(site))

      unquote_splicing(
        for fun <- [
              :beacon_stylesheet_fixture,
              :beacon_component_fixture,
              :beacon_layout_fixture,
              :beacon_published_layout_fixture,
              :beacon_page_fixture,
              :beacon_published_page_fixture,
              :beacon_snippet_helper_fixture,
              :beacon_media_library_asset_fixture,
              :beacon_upload_metadata_fixture,
              :beacon_page_variant_fixture,
              :beacon_event_handler_fixture,
              :beacon_error_page_fixture,
              :beacon_live_data_fixture,
              :beacon_live_data_assign_fixture,
              :beacon_info_handler_fixture
            ] do
          quote do
            def unquote(fun)() do
              apply(Beacon.Test.Fixtures, unquote(fun), [%{site: unquote(site)}])
            end

            def unquote(fun)(attrs) do
              attrs = Fixtures.merge_default_site(attrs, unquote(site))
              apply(Beacon.Test.Fixtures, unquote(fun), [attrs])
            end
          end
        end
      )
    end
  end

  defp get(attrs, key) when is_map(attrs), do: Map.get(attrs, key)
  defp get(attrs, key) when is_list(attrs) and is_atom(key), do: Keyword.get(attrs, key)
  defp get(_attrs, _key), do: nil

  defp get_lazy(attrs, key, fun) when is_map(attrs), do: Map.get_lazy(attrs, key, fun)
  defp get_lazy(attrs, key, fun) when is_list(attrs) and is_atom(key), do: Keyword.get_lazy(attrs, key, fun)
  defp get_lazy(_attrs, _key, _fun), do: nil

  @doc false
  def merge_default_site(attrs, site) when is_list(attrs) do
    Keyword.put_new(attrs, :site, site)
  end

  def merge_default_site(attrs, site) when is_map(attrs) do
    if Map.has_key?(attrs, "site") || Map.has_key?(attrs, :site) do
      attrs
    else
      Map.put(attrs, :site, site)
    end
  end

  defp site(attrs) do
    get(attrs, :site) || get(attrs, "site") || "my_site"
  end

  def beacon_stylesheet_fixture(attrs) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })
    |> Content.create_stylesheet!()
    |> tap(&Loader.reload_stylesheet_module(&1.site))
  end

  @doc """
  Creates a `Beacon.Content.Component`.

  ## Example

      iex> beacon_component_fixture(name: "sample_component")
      %Beacon.Content.Component{}

  """
  @spec beacon_component_fixture(map() | Keyword.t()) :: Beacon.Content.Component.t()
  def beacon_component_fixture(attrs) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "sample_component",
      category: "element",
      attrs: [%{name: "project", type: "any", opts: [required: true]}],
      slots: [],
      template: ~S|<span id={"project-#{@project.id}"}><%= @project.name %></span>|,
      example: ~S|<.sample_component project={%{id: 1, name: "Beacon"}} />|
    })
    |> Content.create_component!()
    |> tap(&Loader.reload_components_module(&1.site))
  end

  def beacon_layout_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      title: "Sample Home Page",
      meta_tags: [],
      resource_links: [],
      template: """
      <%= @inner_content %>
      """
    })
    |> Content.create_layout!()
  end

  def beacon_published_layout_fixture(attrs) do
    {:ok, layout} =
      attrs
      |> beacon_layout_fixture()
      |> Content.publish_layout()

    Loader.reload_layout_module(layout.site, layout.id)

    layout
  end

  @doc """
  Creates a `Beacon.Content.Page`

  ## Examples

      iex> beacon_page_fixture()
      %Beacon.Content.Page{}

      iex> beacon_page_fixture(title: "Home")
      %Beacon.Content.Page{}

  """
  @spec beacon_page_fixture(map() | Keyword.t()) :: Beacon.Content.Page.t()
  def beacon_page_fixture(attrs) do
    layout_id = get_lazy(attrs, :layout_id, fn -> beacon_layout_fixture().id end)

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

  def beacon_published_page_fixture(attrs) do
    site = site(attrs)

    layout_id = get_lazy(attrs, :layout_id, fn -> beacon_published_layout_fixture(site: site).id end)
    attrs = Enum.into(attrs, %{layout_id: layout_id})

    {:ok, page} =
      attrs
      |> beacon_page_fixture()
      |> Content.publish_page()

    Loader.reload_page_module(page.site, page.id)

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

  def beacon_snippet_helper_fixture(attrs) do
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
    |> tap(&Loader.reload_snippets_module(&1.site))
  end

  def beacon_media_library_asset_fixture(attrs) do
    attrs = Map.new(attrs)

    attrs
    |> beacon_upload_metadata_fixture()
    |> MediaLibrary.upload()
  end

  def beacon_upload_metadata_fixture(attrs) do
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

    page_variant =
      page
      |> Ecto.build_assoc(:variants)
      |> PageVariant.changeset(full_attrs)
      |> repo(page).insert!()

    Loader.reload_page_module(page.site, page.id)

    page_variant
  end

  defp template_for(%{format: :heex} = _page), do: "<div>My Site</div>"
  defp template_for(%{format: :markdown} = _page), do: "# My site"

  def beacon_event_handler_fixture(attrs) do
    full_attrs = %{
      name: attrs[:name] || "Event Handler #{System.unique_integer([:positive])}",
      code: attrs[:code] || "{:noreply, socket}",
      site: attrs[:site] || :my_site
    }

    %EventHandler{}
    |> EventHandler.changeset(full_attrs)
    |> repo(full_attrs.site).insert!()
    |> tap(&Loader.reload_event_handlers_module(&1.site))
  end

  def beacon_error_page_fixture(attrs) do
    layout = get_lazy(attrs, :layout, fn -> beacon_layout_fixture() end)

    attrs
    |> Enum.into(%{
      site: "my_site",
      status: Enum.random(ErrorPage.valid_statuses()),
      template: "Uh-oh!",
      layout_id: layout.id
    })
    |> Content.create_error_page!()
    |> tap(&Loader.reload_error_page_module(&1.site))
  end

  def beacon_live_data_fixture(attrs) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      path: "/foo/bar"
    })
    |> Content.create_live_data!()
    |> tap(&Loader.reload_live_data_module(&1.site))
  end

  def beacon_live_data_assign_fixture(attrs) do
    %{site: site} = live_data = get_lazy(attrs, :live_data, fn -> beacon_live_data_fixture(%{}) end)

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

    Loader.reload_live_data_module(site)

    live_data
  end

  def beacon_info_handler_fixture(attrs) do
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
    |> tap(&Loader.reload_info_handlers_module(&1.site))
  end
end
