defmodule Beacon.Content.SiteSetting do
  @moduledoc """
  Site-level settings that control site-wide behavior and templates.

  Settings are key-value pairs scoped to a site, with an optional format
  (`:heex` or `:text`) and description.

  Known keys have default values that are used when no custom setting exists:

    * `"notification_template"` — the HEEx template rendered when a page update
      notification is shown to visitors.

  > #### Do not create or edit site settings manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_site_settings" do
    field :site, Beacon.Types.Site
    field :key, :string
    field :value, :string
    field :format, Beacon.Types.Atom, default: :heex
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(setting \\ %__MODULE__{}, attrs) do
    setting
    |> cast(attrs, [:site, :key, :value, :format, :description])
    |> validate_required([:site, :key, :value])
    |> validate_inclusion(:format, [:heex, :text])
    |> validate_format(:key, ~r/^[a-zA-Z0-9_]+$/, message: "must contain only alphanumeric characters and underscores")
    |> unique_constraint([:site, :key])
  end

  @doc """
  Returns the map of known setting keys with their default values and metadata.
  """
  @spec known_keys() :: map()
  def known_keys do
    %{
      "notification_template" => %{
        default: default_notification_template(),
        format: :heex,
        description: "HEEx template rendered when a page update notification is shown to visitors."
      }
    }
  end

  @doc """
  Returns the default HEEx template for the page update notification.
  """
  @spec default_notification_template() :: String.t()
  def default_notification_template do
    ~S"""
    <div
      id="beacon-update-notification"
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
