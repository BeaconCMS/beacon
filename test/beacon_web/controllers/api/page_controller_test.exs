defmodule BeaconWeb.Controllers.Api.PageControllerTest do
  use BeaconWeb.ConnCase
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
    component_fixture()

    page =
      page_fixture(
        site: :my_site,
        template: ~S"""
        <main>
          <%= my_component("sample_component", val: 1) %>
        </main>

        """
      )

    Beacon.reload_site(:my_site)

    %{page: page}
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
                         "content" => ["my_component(\"sample_component\", val: 1)"],
                         "tag" => "eex",
                         "metadata" => %{"opt" => ~c"="},
                         "renderedHtml" => "<span id=\"my-component-1\">1</span>"
                       }
                     ],
                     "tag" => "main"
                   }
                 ],
                 "format" => "heex",
                 "path" => "/home",
                 "site" => "my_site",
                 "template" => "<main>\n  <%= my_component(\"sample_component\", val: 1) %>\n</main>\n\n"
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
                       "content" => ["my_component(\"sample_component\", val: 1)"],
                       "tag" => "eex",
                       "metadata" => %{"opt" => ~c"="},
                       "renderedHtml" => "<span id=\"my-component-1\">1</span>"
                     }
                   ],
                   "tag" => "main"
                 }
               ],
               "format" => "heex",
               "id" => ^id,
               "path" => "/home",
               "site" => "my_site",
               "template" => "<main>\n  <%= my_component(\"sample_component\", val: 1) %>\n</main>\n\n"
             } = json_response(conn, 200)["data"]
    end
  end

  describe "update layout" do
    setup [:create_page]

    test "renders page when data is valid", %{conn: conn, page: %Page{id: id} = page} do
      conn = put(conn, "/api/my_site/pages/#{page.id}", page: %{path: "/updated_path"})
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, "/api/my_site/pages/#{id}")

      assert %{
               "id" => ^id,
               "path" => "/updated_path"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, page: page} do
      conn = put(conn, "/api/my_site/pages/#{page.id}", page: %{path: nil})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
