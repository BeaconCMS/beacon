defmodule Beacon.Content.Layout do
  @moduledoc """
  Layouts are the wrapper content for `Beacon.Content.Page`.

  > #### Do not create or layouts pages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Beacon.Schema

  @version 1

  @type t :: %__MODULE__{
          id: String.t(),
          site: Beacon.Types.Site.t(),
          title: String.t(),
          body: String.t(),
          meta_tags: [map()],
          stylesheet_urls: [String.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_layouts" do
    field :site, Beacon.Types.Site
    field :title, :string
    field :body, :string
    field :meta_tags, {:array, :map}, default: []
    field :stylesheet_urls, {:array, :string}, default: []

    timestamps()
  end

  @doc """
  Current data structure version.

  Bump when schema changes.
  """
  def version, do: @version

  @doc false
  def changeset(%__MODULE__{} = layout, attrs) do
    layout
    |> cast(attrs, [:site, :title, :body, :meta_tags, :stylesheet_urls])
    |> validate_required([:site, :title, :body])
    |> validate_body()
  end

  defp validate_body(changeset) do
    site = Changeset.get_field(changeset, :site)
    body = Changeset.get_field(changeset, :body, "")
    do_validate_body(changeset, site, body)
  end

  defp do_validate_body(changeset, site, body) when is_atom(site) and is_binary(body) do
    metadata = %Beacon.Template.LoadMetadata{site: site, path: ""}

    case Beacon.Template.HEEx.compile(body, metadata) do
      {:cont, _ast} ->
        changeset

      {:halt, %{description: description}} ->
        add_error(changeset, :body, "invalid", compilation_error: description)

      {:halt, _} ->
        add_error(changeset, :body, "invalid")
    end
  end

  defp do_validate_body(changeset, _site, _body), do: changeset
end
