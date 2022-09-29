defmodule BeaconWeb.LiveHelpers do
  import Phoenix.Component

  @doc """
  Renders a component inside the `BeaconWeb.PageManagement.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal BeaconWeb.PageManagement.PageLive.FormComponent,
        id: @page.id || :new,
        action: @live_action,
        page: @page,
        return_to: Routes.page_index_path(@socket, :index) %>
  """
  def live_modal(component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    live_component(%{module: BeaconWeb.PageManagement.ModalComponent, id: :modal, return_to: path, component: component, opts: opts})
  end
end
