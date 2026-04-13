defmodule Beacon.Auth.UserRole do
  @moduledoc """
  Represents a role assignment for a Beacon user.

  Roles control what actions a user can perform. Site-scoped roles
  (site_admin, site_editor, site_viewer) require a non-nil `site` field.
  The super_admin role has a nil `site` and grants access to all sites.

  ## Valid Roles

    * `"super_admin"` - Full access to all sites and platform settings
    * `"site_admin"` - Full access to a specific site
    * `"site_editor"` - Can edit content on a specific site
    * `"site_viewer"` - Read-only access to a specific site
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  @valid_roles ~w(super_admin site_admin site_editor site_viewer)

  schema "beacon_user_roles" do
    field :role, :string
    field :site, Beacon.Types.Site

    belongs_to :user, Beacon.Auth.User

    timestamps()
  end

  @doc false
  def changeset(user_role \\ %__MODULE__{}, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role, :site])
    |> validate_required([:user_id, :role])
    |> validate_inclusion(:role, @valid_roles, message: "must be one of: #{Enum.join(@valid_roles, ", ")}")
    |> unique_constraint([:user_id, :role, :site])
  end

  def valid_roles, do: @valid_roles
end
