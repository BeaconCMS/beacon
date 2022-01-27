defmodule BeaconWeb.PageManagement do
  defmacro routes do
    quote do
      live("/pages", PageLive.Index, :index)
      live("/pages/new", PageLive.Index, :new)
      live("/page_editor/:id", PageEditorLive, :edit)
    end
  end
end
