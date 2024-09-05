defmodule Beacon.Content.Page.Helper do
  @moduledoc false
  use Ecto.Schema

  embedded_schema do
    field :name, :string
    field :args, :string
    field :code, :string
  end
end
