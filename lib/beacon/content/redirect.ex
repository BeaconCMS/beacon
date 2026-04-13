defmodule Beacon.Content.Redirect do
  @moduledoc """
  Represents a URL redirect rule for a Beacon site.

  Redirects are checked on every request via `Beacon.Plug.Redirect` and
  are cached in ETS for constant-time lookups. When a page's path changes
  at publish time, a 301 redirect is automatically created from the old
  path to the new one.

  Redirect chains are automatically flattened on creation and circular
  redirects are rejected.
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_redirects" do
    field :site, Beacon.Types.Site
    field :source_path, :string
    field :destination_path, :string
    field :status_code, :integer, default: 301
    field :is_regex, :boolean, default: false
    field :priority, :integer, default: 0
    field :hit_count, :integer, default: 0
    field :last_hit_at, :utc_datetime_usec

    timestamps()
  end

  @doc false
  def changeset(redirect \\ %__MODULE__{}, attrs) do
    redirect
    |> cast(attrs, [:site, :source_path, :destination_path, :status_code, :is_regex, :priority])
    |> validate_required([:site, :source_path, :destination_path, :status_code])
    |> validate_inclusion(:status_code, [301, 302, 307, 308])
    |> validate_not_circular()
    |> unique_constraint([:site, :source_path])
  end

  defp validate_not_circular(changeset) do
    validate_change(changeset, :destination_path, fn :destination_path, dest ->
      source = get_field(changeset, :source_path)
      if source == dest, do: [destination_path: "cannot redirect to itself"], else: []
    end)
  end
end
