defmodule Beacon.Pages.Page do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Layouts.Layout
  alias Beacon.Pages.Page
  alias Beacon.Pages.PageEvent
  alias Beacon.Pages.PageHelper
  alias Beacon.Pages.PageVersion
  alias Ecto.Changeset

  @meta_tag_interpolation_keys [:title, :description, :path]

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_pages" do
    field :site, Beacon.Types.Atom
    field :title, :string
    field :description, :string
    field :version, :integer, default: 1
    field :path, :string
    field :template, :string
    field :pending_template, :string
    field :meta_tags, {:array, :map}, default: []
    field :order, :integer, default: 1
    field :status, Ecto.Enum, values: [:draft, :published], default: :draft
    field :format, Beacon.Types.Atom, default: :heex
    field :extra, :map, default: %{}
    field :raw_schema, {:array, :map}, default: []

    belongs_to :layout, Layout
    belongs_to :pending_layout, Layout

    has_many :events, PageEvent
    has_many :helpers, PageHelper
    has_many :versions, PageVersion

    timestamps()
  end

  @doc false
  def changeset(page \\ %Page{}, %{} = attrs) do
    page
    |> cast(attrs, [
      :site,
      :title,
      :description,
      :version,
      :template,
      :meta_tags,
      :order,
      :layout_id,
      :status,
      :format,
      :extra,
      :raw_schema
    ])
    |> cast(attrs, [:path], empty_values: [])
    |> put_pending_template()
    |> validate_required([
      :site,
      :template,
      :layout_id,
      :pending_template,
      :pending_layout_id,
      :version,
      :order,
      :format
    ])
    |> validate_string([:path])
    |> unique_constraint(:id, name: :pages_pkey)
    |> unique_constraint([:path, :site])
    |> foreign_key_constraint(:layout_id)
    |> foreign_key_constraint(:pending_layout_id)
    |> trim([:pending_template])
    |> remove_all_newlines([:description])
    |> remove_empty_meta_attributes(:meta_tags)
  end

  def update_pending_changeset(page, attrs) do
    # TODO: The inclusion of the fields [:title, :description, :meta_tags] here requires some more consideration, but we
    # need them to get going on the admin interface for now
    page
    # TODO: only allow path if status = draft
    |> cast(attrs, [:pending_template, :pending_layout_id, :title, :description, :meta_tags, :path, :format, :raw_schema])
    |> validate_required([:pending_template, :pending_layout_id])
    |> trim([:pending_template])
    |> remove_all_newlines([:description])
    |> remove_empty_meta_attributes(:meta_tags)
  end

  # TODO: The inclusion of the fields [:title, :description, :meta_tags] here requires some more consideration, but we
  # need them to get going on the admin interface for now
  # TODO: only allow path if status = draft
  @doc false
  def update_page_changeset(page, attrs) do
    {extra_attrs, attrs} = Map.pop(attrs, "extra")

    page
    |> cast(attrs, [
      :pending_template,
      :pending_layout_id,
      :title,
      :description,
      :meta_tags,
      :path,
      :format,
      :raw_schema
    ])
    |> validate_required([:pending_template, :pending_layout_id])
    |> trim([:pending_template])
    |> remove_all_newlines([:description])
    |> remove_empty_meta_attributes(:meta_tags)
    |> Beacon.PageField.apply_changesets(page.site, extra_attrs)
  end

  def put_pending_template(%Changeset{} = changeset) do
    changeset =
      case get_change(changeset, :template) do
        nil -> changeset
        template -> put_change(changeset, :pending_template, template)
      end

    case get_change(changeset, :layout_id) do
      nil -> changeset
      layout_id -> put_change(changeset, :pending_layout_id, layout_id)
    end
  end

  def validate_string(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      case get_field(changeset, field) do
        val when is_binary(val) -> changeset
        _ -> add_error(changeset, field, "Not a string")
      end
    end)
  end

  defp trim(changeset, fields) do
    Enum.reduce(fields, changeset, fn f, cs ->
      update_change(cs, f, fn
        value when is_binary(value) -> String.trim(value)
        value -> value
      end)
    end)
  end

  # For when the UI is a <textarea> but "\n" would cause problems
  defp remove_all_newlines(changeset, fields) do
    Enum.reduce(fields, changeset, fn f, cs ->
      update_change(cs, f, fn
        value when is_binary(value) ->
          value
          |> String.trim()
          |> String.replace(~r/\n+/, " ")

        value ->
          value
      end)
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

  @doc """
  Returns the list of Page fields which are available to the end user for interpolating into the values of meta
  tag attributes.

  The interpolation syntax is to surround the field name with %. For example, to insert the page :title, the user would
  provide the value "%title%".
  """
  def meta_tag_interpolation_keys, do: @meta_tag_interpolation_keys
end
