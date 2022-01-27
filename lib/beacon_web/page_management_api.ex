defmodule BeaconWeb.PageManagementApi do
  defmacro routes do
    quote do
      get("/pages", PageController, :index)
      get("/pages/:id", PageController, :show)
      post("/pages", PageController, :create)
      put("/pages/:id", PageController, :update_page_pending)
      post("/pages/:id/publish", PageController, :publish)

      get("/layouts", LayoutController, :index)
      get("/layouts/:id", LayoutController, :show)
    end
  end
end
