defmodule BeaconWeb.Controllers.Api.ComponentControllerTest do
  use BeaconWeb.ConnCase, async: false
  import Beacon.Fixtures

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  defp create_component(_) do
    layout = published_layout_fixture(site: :my_site)

    component =
      component_fixture(
        site: :my_site,
        body: """
        <div id="component"><%= List.first(@beacon_live_data[:vals]) %></div>
        """
      )

    page = published_page_fixture(site: :my_site, layout_id: layout.id)
    Beacon.Loader.load_page(page)
    %{page: page, component: component}
  end

  describe "index" do
    setup [:create_component]

    test "lists all components", %{conn: conn} do
      conn = get(conn, "/api/my_site/components")

      assert [
               %{
                 "body" => "<div id=\"component\"><%= List.first(@beacon_live_data[:vals]) %></div>\n",
                 "category" => "other",
                 "name" => "sample_component",
                 "thumbnail" => nil
               }
             ] = json_response(conn, 200)["data"]
    end
  end

  describe "show" do
    setup [:create_component]

    test "show a component", %{conn: conn, component: component} do
      id = component.id
      conn = get(conn, "/api/my_site/components/#{id}")

      assert %{
               "body" => "<div id=\"component\"><%= List.first(@beacon_live_data[:vals]) %></div>\n",
               "category" => "other",
               "id" => ^id,
               "name" => "sample_component",
               "thumbnail" => nil
             } = json_response(conn, 200)["data"]
    end

    test "show with @beacon_live_data", %{conn: conn, page: page, component: component} do
      id = component.id
      conn = get(conn, "/api/my_site/pages/#{page.id}/components/#{id}")

      assert %{
               "body" => "<div id=\"component\"><%= List.first(@beacon_live_data[:vals]) %></div>\n",
               "category" => "other",
               "id" => ^id,
               "name" => "sample_component",
               "thumbnail" => nil,
               "ast" => [
                 %{
                   "attrs" => %{"id" => "component"},
                   "content" => [
                     %{
                       "attrs" => %{},
                       "content" => ["List.first(@beacon_live_data[:vals])"],
                       "metadata" => %{"opt" => ~c"="},
                       "renderedHtml" => "first",
                       "tag" => "eex"
                     }
                   ],
                   "tag" => "div"
                 }
               ]
             } = json_response(conn, 200)["data"]
    end
  end
end
