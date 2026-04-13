defmodule Beacon.Content.InternalLink do
  @moduledoc """
  Represents an internal link between two pages.

  Links are extracted from rendered page HTML at publish time and stored
  for orphan page detection and broken link analysis.
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_internal_links" do
    field :site, Beacon.Types.Site
    field :source_page_id, Ecto.UUID
    field :target_page_id, Ecto.UUID
    field :target_path, :string
    field :anchor_text, :string

    timestamps updated_at: false
  end
end
