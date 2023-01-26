defmodule BeaconWeb.Admin do
  defmacro routes do
    quote do
      live "/", HomeLive.Index, :index

      live "/pages", PageLive.Index, :index
      live "/pages/new", PageLive.Index, :new
      live "/page_editor/:id", PageEditorLive, :edit

      live "/media_library", MediaLibraryLive.Index, :index
      live "/media_library/upload", MediaLibraryLive.Index, :upload
    end
  end
end
