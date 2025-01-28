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

  ## Fixtures

  All fixtures accept either a map or a keyword list, so these are equivalent:

  ```elixir
  beacon_page_fixture(path: "/contact")
  beacon_page_fixture(%{path: "/contact"})
  beacon_page_fixture(%{"path" => "/contact"})
  ```

  Or no attributes at all to use the default values:

  ```elixir
  beacon_page_fixture()
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

  # FIXME: remove Beacon.Loader dependency in favor of the new optimized :error_handler loader,
  #        so it does not trigger a reload for _every_ fixture call, which makes the tests suite slower.

  alias Beacon.Content
  alias Beacon.Content.ErrorPage
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

  @doc """
  Creates a `Beacon.Content.Stylesheet`.

  ## Example

      iex> beacon_stylesheet_fixture(content: "h1 { color: red; }")
      %Beacon.Content.Stylesheet{}

  """
  @spec beacon_stylesheet_fixture(map() | Keyword.t()) :: Beacon.Content.Stylesheet.t()
  def beacon_stylesheet_fixture(attrs) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "sample_stylesheet",
      content: "body {cursor: zoom-in;}"
    })
    |> Content.create_stylesheet!(auth: false)
    |> tap(&Loader.load_stylesheet_module(&1.site))
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
    |> Content.create_component!(auth: false)
    |> tap(&Loader.load_components_module(&1.site))
  end

  @doc """
  Creates a draft `Beacon.Content.Layout`.

  ## Examples

      iex> beacon_layout_fixture()
      %Beacon.Content.Layout{}

      iex> beacon_layout_fixture(template: "<%= @inner_content %>")
      %Beacon.Content.Layout{}

  """
  @spec beacon_layout_fixture(map() | Keyword.t()) :: Beacon.Content.Layout.t()
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
    |> Content.create_layout!(auth: false)
  end

  @doc """
  Similar to `beacon_layout_fixture/1`, but also publishes the layout.
  """
  @spec beacon_published_layout_fixture(map() | Keyword.t()) :: Beacon.Content.Layout.t()
  def beacon_published_layout_fixture(attrs) do
    {:ok, layout} =
      attrs
      |> beacon_layout_fixture()
      |> Content.publish_layout(auth: false)

    Loader.load_layout_module(layout.site, layout.id)

    layout
  end

  @doc """
  Creates a draft `Beacon.Content.Page`

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
    |> Content.create_page!(auth: false)
  end

  @doc """
  Similar to `beacon_page_fixture/1`, but also publishes the page.
  """
  @spec beacon_published_page_fixture(map() | Keyword.t()) :: Beacon.Content.Page.t()
  def beacon_published_page_fixture(attrs) do
    site = site(attrs)

    layout_id = get_lazy(attrs, :layout_id, fn -> beacon_published_layout_fixture(site: site).id end)
    attrs = Enum.into(attrs, %{layout_id: layout_id})

    {:ok, page} =
      attrs
      |> beacon_page_fixture()
      |> Content.publish_page(auth: false)

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

  @doc """
  Creates a `Beacon.Content.Snippets.Helper`.

  ## Example

      iex> beacon_snippet_helper_fixture(body: ~S\"\"\"
        assigns |> get_in(["page", "title"]) |> String.trim()
      \"\"\")
      %Beacon.Content.Snippets.Helper{}

  """
  @spec beacon_snippet_helper_fixture(map() | Keyword.t()) :: Beacon.Content.Snippets.Helper.t()
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
    |> Content.create_snippet_helper!(auth: false)
    |> tap(&Loader.load_snippets_module(&1.site))
  end

  @doc """
  Uploads a given "upload metadata" created by `beacon_upload_metadata_fixture/1`.

  ## Example

      iex> beacon_media_library_asset_fixture(upload_metadata)
      %Beacon.MediaLibrary.Asset{}

  """
  @spec beacon_media_library_asset_fixture(map() | Keyword.t()) :: Beacon.MediaLibrary.Asset.t()
  def beacon_media_library_asset_fixture(attrs) do
    attrs
    |> Map.new()
    |> beacon_upload_metadata_fixture()
    |> MediaLibrary.upload()
  end

  @doc """
  Creates a `Beacon.MediaLibrary.UploadMetadata`.

  ## Example

      iex> beacon_upload_metadata_fixture(file_size: 100_000)
      %Beacon.MediaLibrary.UploadMetadata{}

  """
  @spec beacon_upload_metadata_fixture(map() | Keyword.t()) :: Beacon.MediaLibrary.UploadMetadata.t()
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

    UploadMetadata.new(attrs.site, attrs.file_path, Node.self(), name: attrs.file_name, size: attrs.file_size, extra: attrs.extra)
  end

  defp path_for(file_name) do
    ext = Path.extname(file_name)
    file_name = "image#{ext}"

    Path.join(["test", "support", "fixtures", file_name])
  end

  @doc """
  Creates a `Beacon.Content.PageVariant`.

  ## Example

      iex> beacon_page_variant_fixture(page: page, weight: 50, template: "<h1>Variant B</h1>")
      %Beacon.Content.PageVariant{}

  """
  @spec beacon_page_variant_fixture(map() | Keyword.t()) :: Beacon.Content.PageVariant.t()
  def beacon_page_variant_fixture(%{page: %Content.Page{} = page} = attrs), do: beacon_page_variant_fixture(page, attrs)

  def beacon_page_variant_fixture(%{site: site, page_id: page_id} = attrs) do
    site
    |> Content.get_page!(page_id)
    |> beacon_page_variant_fixture(attrs)
  end

  defp beacon_page_variant_fixture(page, attrs) do
    attrs =
      Enum.into(attrs, %{
        name: "Variant #{System.unique_integer([:positive])}",
        weight: Enum.random(1..10),
        template: template_for(page)
      })

    page
    |> Ecto.build_assoc(:variants)
    |> Content.PageVariant.changeset(attrs)
    |> repo(page).insert!()
  end

  defp template_for(%{format: :heex} = _page), do: "<div><h1>My Site</h1></div>"
  defp template_for(%{format: :markdown} = _page), do: "# My site"

  @doc """
  Creates a `Beacon.Content.EventHandler`.

  ## Example

      iex> beacon_event_handler_fixture(code: ~S\"\"\"
        email = event_params["newsletter"]["email"]
        MyApp.Newsletter.subscribe(email)
        {:noreply, socket}
      "\"\"\)
      %Beacon.Content.EventHandler{}

  """
  @spec beacon_event_handler_fixture(map() | Keyword.t()) :: Beacon.Content.EventHandler.t()
  def beacon_event_handler_fixture(attrs) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      name: "Event Handler #{System.unique_integer([:positive])}",
      code: "{:noreply, socket}"
    })
    |> Content.create_event_handler!(auth: false)
    |> tap(&Loader.load_event_handlers_module(&1.site))
  end

  @doc """
  Creates a `Beacon.Content.ErrorPage`.

  ## Example

      iex> beacon_error_page_fixture(status: 404, template: "nothing here")
      %Beacon.Content.ErrorPage{}

  """
  @spec beacon_error_page_fixture(map() | Keyword.t()) :: Beacon.Content.ErrorPage.t()
  def beacon_error_page_fixture(attrs) do
    layout = get_lazy(attrs, :layout, fn -> beacon_layout_fixture() end)

    attrs
    |> Enum.into(%{
      site: "my_site",
      status: Enum.random(ErrorPage.valid_statuses()),
      template: "Uh-oh!",
      layout_id: layout.id
    })
    |> Content.create_error_page!(auth: false)
    |> tap(&Loader.load_error_page_module(&1.site))
  end

  @doc """
  Creates a `Beacon.Content.LiveData`.

  ## Example

      iex> beacon_live_data_fixture(path: "/contact")
      %Beacon.Content.LiveData{}

  """
  @spec beacon_live_data_fixture(map() | Keyword.t()) :: Beacon.Content.LiveData.t()
  def beacon_live_data_fixture(attrs) do
    attrs
    |> Enum.into(%{
      site: "my_site",
      path: "/foo/bar"
    })
    |> Content.create_live_data!(auth: false)
    |> tap(&Loader.load_live_data_module(&1.site))
  end

  @doc """
  Creates a `Beacon.Content.LiveDataAssign`.

  ## Example

      iex> beacon_live_data_assign_fixture(live_data: live_data, key: "user", value: "%{id: 1, name: \"John\"}")
      %Beacon.Content.LiveDataAssign{}

  """
  @spec beacon_live_data_assign_fixture(map() | Keyword.t()) :: Beacon.Content.LiveDataAssign.t()
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

    Loader.load_live_data_module(site)

    live_data
  end

  @doc """
  Creates a `Beacon.Content.InfoHandler`.

  ## Example

      iex> beacon_info_handler_fixture(msg: "{:subscribed, email}", code: ~S\"\"\"
      MyApp.Notifications.send_email(email, "Welcome!")
      {:noreply, socket}
      \"\"\")
      %Beacon.Content.InfoHandler{}

  """
  @spec beacon_info_handler_fixture(map() | Keyword.t()) :: Beacon.Content.InfoHandler.t()
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

    attrs
    |> Enum.into(%{
      site: "my_site",
      msg: msg,
      code: code
    })
    |> Content.create_info_handler!(auth: false)
    |> tap(&Loader.load_info_handlers_module(&1.site))
  end
end
