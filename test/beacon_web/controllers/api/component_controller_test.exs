defmodule BeaconWeb.Controllers.Api.ComponentControllerTest do
  use BeaconWeb.ConnCase
  import Beacon.Fixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  defp create_component(_) do
    component = component_fixture(site: :my_site)
    %{component: component}
  end

  describe "index" do
    setup [:create_component]

    test "lists all components", %{conn: conn} do
      conn = get(conn, "/api/my_site/components")

      assert [
               %{
                 "body" => "<span id={\"my-component-\#{@val}\"}><%= @val %></span>\n",
                 "category" => "other",
                 "name" => "sample_component"
               }
             ] = json_response(conn, 200)["data"]
    end
  end
end
