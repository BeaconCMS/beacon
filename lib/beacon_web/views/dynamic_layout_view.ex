defmodule BeaconWeb.DynamicLayoutView do
  use BeaconWeb, :view

  require Logger

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def render_layout(%{__dynamic_layout_id__: layout_id, __site__: site} = assigns) do
    module = Beacon.Loader.layout_module_for_site(site)

    Beacon.Loader.call_function_with_retry(module, :render, [layout_id, assigns])
  end
end
