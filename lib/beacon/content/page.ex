defmodule Beacon.Content.Page do
  @moduledoc """
  Pages are the central piece of content in Beacon used to render templates with meta tags, components, and other resources.

  Pages are rendered as a LiveView handled by Beacon.

  Pages can be extended with custom fields, see `Beacon.Content.PageField`

  ## SEO

  Meta Tags

  Raw Schema

  > #### Do not create or edit pages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Beacon.Content.Layout
  alias Beacon.Content.Page

  @version 1

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_pages" do
    field :site, Beacon.Types.Site
    field :path, :string
    field :title, :string
    field :description, :string
    field :template, :string
    field :meta_tags, {:array, :map}, default: []
    field :raw_schema, {:array, :map}, default: []
    field :order, :integer, default: 1
    field :format, Beacon.Types.Atom, default: :heex
    field :extra, :map, default: %{}

    belongs_to :layout, Layout

    embeds_many :events, Event do
      field :name, :string
      field :code, :string
    end

    embeds_many :helpers, Helper do
      field :name, :string
      field :args, :string
      field :code, :string
    end

    timestamps()
  end

  @doc """
  Current data structure version.

  Bump when schema changes.
  """
  def version, do: @version

  @doc false
  def changeset(%__MODULE__{} = page, attrs) do
    page
    |> cast(attrs, [
      :site,
      :path,
      :title,
      :description,
      :template,
      :meta_tags,
      :raw_schema,
      :order,
      :layout_id,
      :format,
      :extra
    ])
    |> cast_embed(:events, with: &events_changeset/2)
    |> cast_embed(:helpers, with: &helpers_changeset/2)
    |> validate_required([
      :site,
      :template,
      :layout_id,
      :format
    ])
    |> unique_constraint([:path, :site])
    |> foreign_key_constraint(:layout_id)
    |> validate_string([:path])
    |> remove_empty_meta_attributes(:meta_tags)
  end

  defp events_changeset(schema, params) do
    schema
    |> cast(params, [:name, :code])
    |> validate_required([:name, :code])
  end

  defp helpers_changeset(schema, params) do
    schema
    |> cast(params, [:name, :args, :code])
    |> validate_required([:name, :code])
  end

  defp validate_string(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      case get_field(changeset, field) do
        val when is_binary(val) -> changeset
        _ -> add_error(changeset, field, "Not a string")
      end
    end)
  end

  defp remove_empty_meta_attributes(changeset, field) do
    update_change(changeset, field, fn
      meta_tags when is_list(meta_tags) ->
        Enum.map(meta_tags, &reject_empty_values/1)

      value ->
        value
    end)
  end

  defp reject_empty_values(meta_tag) do
    meta_tag
    |> Enum.reject(fn {_key, value} -> is_nil(value) || String.trim(value) == "" end)
    |> Map.new()
  end
end
