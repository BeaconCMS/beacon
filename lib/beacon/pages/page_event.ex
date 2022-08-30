defmodule Beacon.Pages.PageEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Pages.PageEvent

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_page_events" do
    field :code, :string
    field :event_name, :string
    field :order, :integer, default: 1
    field :page_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(page_event \\ %PageEvent{}, attrs) do
    page_event
    |> cast(attrs, [:code, :order, :event_name, :page_id])
    |> validate_required([:code, :order, :event_name, :page_id])
  end
end
