defmodule BeaconWeb.PageManagementApi.PageController do
  use BeaconWeb, :controller

  alias Beacon.Pages
  alias Beacon.Pages.Page

  action_fallback BeaconWeb.PageManagementApi.FallbackController

  def index(conn, _params) do
    pages = Pages.list_pages()
    render(conn, :index, pages: pages)
  end

  def create(conn, %{"page" => page_params}) do
    with {:ok, %Page{} = page} <- Pages.create_page(page_params) do
      conn
      |> put_status(:created)
      # |> put_resp_header("location", Routes.page_path(conn, :show, page))
      |> render(:show, page: page)
    end
  end

  def show(conn, %{"id" => id}) do
    page = Pages.get_page!(id, [:versions, :layout, :pending_layout])
    render(conn, :show, page: page)
  end

  def update_page_pending(conn, %{"id" => id, "page" => page_params}) do
    page = Pages.get_page!(id)

    case Map.split(page_params, ["template", "layout_id"]) do
      {_, others} when others != %{} ->
        raise "update_page_pending only supports template and layout_id keys"

      {%{"template" => template, "layout_id" => layout_id}, %{}} ->
        with {:ok, %Page{} = page} <- Pages.update_page_pending(page, template, layout_id) do
          render(conn, :show, page: page)
        end

      _ ->
        raise "update_page_pending requires template and layout_id keys"
    end
  end

  def publish(conn, %{"id" => id}) do
    page = Pages.get_page!(id)

    with {:ok, %Page{} = page} <- Pages.publish_page(page) do
      render(conn, :show, page: page)
    end
  end

  # def delete(conn, %{"id" => id}) do
  #   page = Pages.get_page!(id)

  #   with {:ok, %Page{}} <- Pages.delete_page(page) do
  #     send_resp(conn, :no_content, "")
  #   end
  # end
end
