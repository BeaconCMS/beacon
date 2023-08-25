defmodule BeaconWeb.Controllers.Api.PageControllerTest do
  use BeaconWeb.ConnCase
  import Beacon.Fixtures
  alias Beacon.Content.Page

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  defp create_page(_) do
    page = page_fixture()
    %{page: page}
  end

  describe "index" do
    test "lists all pages", %{conn: conn} do
      page_fixture(site: :my_site)
      conn = get(conn, "/api/my_site/pages")

      assert [
               %{
                 "ast" => [%{"attrs" => %{}, "content" => [%{"attrs" => %{}, "content" => ["my_site#home"], "tag" => "h1"}], "tag" => "main"}],
                 "format" => "heex",
                 "path" => "/home",
                 "site" => "my_site",
                 "template" => "<main>\n  <h1>my_site#home</h1>\n</main>\n"
               }
             ] = json_response(conn, 200)["data"]
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
