defmodule Beacon.Pages.Page do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Layouts.Layout
  alias Beacon.Pages.Page
  alias Beacon.Pages.PageEvent
  alias Beacon.Pages.PageHelper
  alias Beacon.Pages.PageVersion
  alias Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_pages" do
    field :site, Beacon.Type.Site
    field :title, :string
    field :description, :string
    field :version, :integer, default: 1
    field :path, :string
    field :template, :string
    field :pending_template, :string
    field :meta_tags, {:array, :map}, default: []
    field :order, :integer, default: 1

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
    |> cast(attrs, [:site, :title, :description, :version, :template, :meta_tags, :order, :layout_id])
    |> cast(attrs, [:path], empty_values: [])
    |> put_pending()
    |> validate_required([
      :site,
      :template,
      :layout_id,
      :pending_template,
      :pending_layout_id,
      :version,
      :order
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
    page
    |> cast(attrs, [:pending_template, :pending_layout_id, :title, :description, :meta_tags])
    |> validate_required([:pending_template, :pending_layout_id])
    |> trim([:pending_template])
    |> remove_all_newlines([:description])
    |> remove_empty_meta_attributes(:meta_tags)
  end

  def put_pending(%Changeset{} = changeset) do
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
      update_change(cs, f, &String.trim/1)
    end)
  end

  defp remove_all_newlines(changeset, fields) do
    Enum.reduce(fields, changeset, fn f, cs ->
      update_change(cs, f, fn value ->
        value
        |> String.trim()
        |> String.replace(~r/\n+/, " ")
      end)
    end)
  end

  defp remove_empty_meta_attributes(changeset, field) do
    update_change(changeset, field, fn meta_tags ->
      Enum.map(meta_tags, fn meta_tag ->
        Map.reject(meta_tag, fn {_, value} -> String.trim(value) == "" end)
      end)
    end)
  end
end
