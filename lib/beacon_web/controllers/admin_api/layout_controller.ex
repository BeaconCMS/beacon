defmodule BeaconWeb.AdminApi.LayoutController do
  use BeaconWeb, :controller

  alias Beacon.Layouts

  action_fallback BeaconWeb.FallbackController

  def index(conn, _params) do
    layouts = Layouts.list_layouts()
    render(conn, :index, layouts: layouts)
  end

  # def create(conn, %{"layout" => layout_params}) do
  #   with {:ok, %Layout{} = layout} <- Layouts.create_layout(layout_params) do
  #     conn
  #     |> put_status(:created)
  #     |> put_resp_header("location", Routes.layout_path(conn, :show, layout))
  #     |> render(:show, layout: layout)
  #   end
  # end

  def show(conn, %{"id" => id}) do
    layout = Layouts.get_layout!(id)
    render(conn, :show, a_layout: layout)
  end

  # def update(conn, %{"id" => id, "layout" => layout_params}) do
  #   layout = Layouts.get_layout!(id)

  #   with {:ok, %Layout{} = layout} <- Layouts.update_layout(layout, layout_params) do
  #     render(conn, :show, layout: layout)
  #   end
  # end

  # def delete(conn, %{"id" => id}) do
  #   layout = Layouts.get_layout!(id)

  #   with {:ok, %Layout{}} <- Layouts.delete_layout(layout) do
  #     send_resp(conn, :no_content, "")
  #   end
  # end
end
