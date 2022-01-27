defmodule Beacon.Pages.Page do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Layouts.Layout
  alias Beacon.Pages.Page
  alias Beacon.Pages.PageVersion
  alias Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "pages" do
    field(:path, :string)
    field(:site, :string)
    field(:template, :string)
    field(:pending_template, :string)
    field(:version, :integer, default: 1)

    belongs_to(:layout, Layout)
    belongs_to(:pending_layout, Layout)

    has_many(:versions, PageVersion)

    timestamps()
  end

  @doc false
  def changeset(page \\ %Page{}, %{} = attrs) do
    page
    |> cast(attrs, [:path, :site, :template, :layout_id, :version])
    |> put_pending()
    |> validate_required([
      :path,
      :site,
      :template,
      :layout_id,
      :pending_template,
      :pending_layout_id,
      :version
    ])
    |> unique_constraint(:id, name: :pages_pkey)
    |> unique_constraint([:path, :site])
    |> foreign_key_constraint(:layout_id)
    |> foreign_key_constraint(:pending_layout_id)
  end

  def update_pending_changeset(page, attrs) do
    page
    |> cast(attrs, [:pending_template, :pending_layout_id])
    |> validate_required([:pending_template, :pending_layout_id])
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
end
