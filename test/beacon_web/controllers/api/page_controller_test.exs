defmodule BeaconWeb.Controllers.Api.PageControllerTest do
  use BeaconWeb.ConnCase, async: false
  import Beacon.Fixtures
  alias Beacon.Content.Page

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  defp create_page(_) do
    layout = published_layout_fixture(site: :my_site)
    component_fixture(site: :my_site)

    page =
      published_page_fixture(
        site: :my_site,
        layout_id: layout.id,
        template: ~S"""
        <main>
          <%= my_component("sample_component", val: List.first(@beacon_live_data[:vals])) %>
        </main>
        """
      )

    Beacon.Loader.load_page(page)

    %{layout: layout, page: page}
  end

  describe "index" do
    setup [:create_page]

    test "lists all pages", %{conn: conn} do
      conn = get(conn, "/api/my_site/pages")

      assert [
               %{
                 "ast" => [
                   %{
                     "attrs" => %{},
                     "content" => [
                       %{
                         "attrs" => %{},
                         "content" => ["my_component(\"sample_component\", val: List.first(@beacon_live_data[:vals]))"],
                         "metadata" => %{"opt" => ~c"="},
                         "renderedHtml" => "<span id=\"my-component-first\">first</span>",
                         "tag" => "eex"
                       }
                     ],
                     "tag" => "main"
                   }
                 ],
                 "format" => "heex",
                 "path" => "/home",
                 "site" => "my_site",
                 "template" => "<main>\n  <%= my_component(\"sample_component\", val: List.first(@beacon_live_data[:vals])) %>\n</main>\n"
               }
             ] = json_response(conn, 200)["data"]
    end
  end

  describe "show" do
    setup [:create_page]

    test "show a page", %{conn: conn, page: page} do
      id = page.id
      conn = get(conn, "/api/my_site/pages/#{id}")

      assert %{
               "ast" => [
                 %{
                   "attrs" => %{},
                   "content" => [
                     %{
                       "attrs" => %{},
                       "content" => ["my_component(\"sample_component\", val: List.first(@beacon_live_data[:vals]))"],
                       "metadata" => %{"opt" => ~c"="},
                       "renderedHtml" => "<span id=\"my-component-first\">first</span>",
                       "tag" => "eex"
                     }
                   ],
                   "tag" => "main"
                 }
               ],
               "format" => "heex",
               "id" => ^id,
               "path" => "/home",
               "site" => "my_site",
               "template" => "<main>\n  <%= my_component(\"sample_component\", val: List.first(@beacon_live_data[:vals])) %>\n</main>\n"
             } = json_response(conn, 200)["data"]
    end

    test "include layout", %{conn: conn, layout: layout, page: page} do
      layout_id = layout.id
      page_id = page.id

      conn = get(conn, "/api/my_site/pages/#{page_id}?include=layout")

      assert %{
               "layout" => %{
                 "id" => ^layout_id,
                 "metaTags" => [],
                 "resourceLinks" => [],
                 "site" => "my_site",
                 "template" => "<header>Page header</header>\n<%= @inner_content %>\n<footer>Page footer</footer>\n",
                 "title" => "Sample Home Page",
                 "ast" => [
                   %{"attrs" => %{}, "content" => ["Page header"], "tag" => "header"},
                   %{
                     "attrs" => %{},
                     "content" => ["@inner_content"],
                     "metadata" => %{"opt" => ~c"="},
                     "renderedHtml" =>
                       "&lt;main&gt;\n  &lt;%= my_component(&quot;sample_component&quot;, val: List.first(@beacon_live_data[:vals])) %&gt;\n&lt;/main&gt;\n",
                     "tag" => "eex"
                   },
                   %{"attrs" => %{}, "content" => ["Page footer"], "tag" => "footer"}
                 ]
               }
             } = json_response(conn, 200)["data"]
    end
  end

  describe "update layout" do
    setup [:create_page]

    test "renders page when data is valid", %{conn: conn, page: %Page{id: id} = page} do
      conn = put(conn, "/api/my_site/pages/#{page.id}", page: %{template: "<div>home</div>"})
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, "/api/my_site/pages/#{id}")

      assert %{
               "id" => ^id,
               "path" => "/home",
               "template" => "<div>home</div>"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, page: page} do
      conn = put(conn, "/api/my_site/pages/#{page.id}", page: %{path: nil})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
