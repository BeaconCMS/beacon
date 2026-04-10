defmodule Beacon.Web.Components.UpdateNotification do
  @moduledoc """
  Default notification component shown when a page has been updated
  and the `live_update` mode is set to `:notify`.

  This component renders a fixed-position notification bar with a
  "Refresh" button that triggers the `beacon:apply-update` event
  and a dismiss button.

  You can replace this with a custom component by setting
  `update_notification_component` in your Beacon config.
  """

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div
      id="beacon-update-notification"
      class="beacon-update-notification"
      style="position:fixed;bottom:1rem;right:1rem;z-index:9999;background:#1a1a2e;color:white;padding:0.75rem 1.25rem;border-radius:0.5rem;box-shadow:0 4px 12px rgba(0,0,0,0.15);display:flex;align-items:center;gap:0.75rem;font-family:system-ui,sans-serif;font-size:0.875rem;"
    >
      <span>This page has been updated</span>
      <button
        phx-click="beacon:apply-update"
        style="background:#4361ee;color:white;border:none;padding:0.375rem 0.75rem;border-radius:0.25rem;cursor:pointer;font-size:0.875rem;"
      >
        Refresh
      </button>
      <button
        phx-click="beacon:dismiss-update"
        style="background:transparent;color:#999;border:none;cursor:pointer;font-size:1rem;padding:0 0.25rem;"
      >
        &times;
      </button>
    </div>
    """
  end
end
