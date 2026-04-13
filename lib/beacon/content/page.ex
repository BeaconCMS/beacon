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
  use Beacon.Schema

  alias Beacon.Content
  alias Beacon.Content.Page.Helper

  @version 5

  @type t :: %__MODULE__{}

  schema "beacon_pages" do
    field :site, Beacon.Types.Site
    field :path, :string
    field :title, :string
    field :description, :string
    field :template, :string
    field :meta_tags, {:array, :map}, default: []
    field :raw_schema, Beacon.Types.JsonArrayMap, default: []
    field :meta_description, :string
    field :canonical_url, :string
    field :robots, :string
    field :og_title, :string
    field :og_description, :string
    field :og_image, :string
    field :twitter_card, :string
    field :page_type, :string, default: "website"
    field :date_modified, :utc_datetime_usec
    field :faq_items, {:array, :map}, default: []
    field :author_id, Ecto.UUID
    field :order, :integer, default: 1
    field :format, Beacon.Types.Atom, default: :heex
    field :extra, :map, default: %{}
    field :ast, :map

    belongs_to :layout, Content.Layout

    has_many :variants, Content.PageVariant
    has_many :page_queries, Content.PageQuery

    embeds_many :helpers, Helper

    timestamps()
  end

  @doc """
  Current data structure version.

  Bump when schema changes.
  """
  def version, do: @version

  @doc false
  def create_changeset(%__MODULE__{} = page, attrs) do
    {extra_attrs, attrs} = Map.pop(attrs, "extra")

    changeset =
      page
      |> cast(attrs, [
        :site,
        :path,
        :title,
        :description,
        :template,
        :meta_tags,
        :raw_schema,
        :meta_description,
        :canonical_url,
        :robots,
        :og_title,
        :og_description,
        :og_image,
        :twitter_card,
        :page_type,
        :date_modified,
        :faq_items,
        :author_id,
        :order,
        :layout_id,
        :format,
        :extra,
        :ast
      ])
      |> maybe_set_date_modified()
      |> cast_embed(:helpers, with: &helpers_changeset/2)
      |> unique_constraint([:path, :site])
      |> validate_required([
        :site,
        :layout_id,
        :path,
        :title,
        :format
      ])
      |> Beacon.Schema.validate_path()
      |> foreign_key_constraint(:layout_id)
      |> remove_empty_meta_attributes(:meta_tags)

    changeset
    |> Content.PageField.apply_changesets(get_field(changeset, :site), extra_attrs)
    |> apply_cache_ttl(extra_attrs)
  end

  # TODO: The inclusion of the fields [:title, :description, :meta_tags] here requires some more consideration, but we
  # need them to get going on the admin interface for now
  # TODO: only allow path if status = draft
  @doc false
  def update_changeset(page, attrs \\ %{}) do
    {extra_attrs, attrs} = Map.pop(attrs, "extra")

    page
    |> cast(attrs, [
      :template,
      :layout_id,
      :title,
      :description,
      :meta_tags,
      :raw_schema,
      :meta_description,
      :canonical_url,
      :robots,
      :og_title,
      :og_description,
      :og_image,
      :twitter_card,
      :page_type,
      :date_modified,
      :faq_items,
      :author_id,
      :format
    ])
    |> cast(attrs, [:path], empty_values: [])
    |> unique_constraint([:path, :site])
    |> validate_required([
      :site,
      :layout_id,
      :format
    ])
    |> Beacon.Schema.validate_path()
    |> remove_all_newlines([:description])
    |> remove_empty_meta_attributes(:meta_tags)
    |> Content.PageField.apply_changesets(page.site, extra_attrs)
    |> apply_cache_ttl(extra_attrs)
  end

  @doc false
  def apply_cache_ttl(changeset, %{"cache_ttl" => raw}) do
    extra = get_field(changeset, :extra) || %{}

    case parse_cache_ttl_input(raw) do
      :remove ->
        put_change(changeset, :extra, Map.delete(extra, "cache_ttl"))

      {:ok, value} ->
        put_change(changeset, :extra, Map.put(extra, "cache_ttl", value))

      :ignore ->
        changeset
    end
  end

  def apply_cache_ttl(changeset, _), do: changeset

  defp parse_cache_ttl_input(nil), do: :ignore
  defp parse_cache_ttl_input(""), do: :remove
  defp parse_cache_ttl_input("infinity"), do: {:ok, "infinity"}

  defp parse_cache_ttl_input(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n >= 0 -> {:ok, n}
      _ -> :ignore
    end
  end

  defp parse_cache_ttl_input(n) when is_integer(n) and n >= 0, do: {:ok, n}
  defp parse_cache_ttl_input(:infinity), do: {:ok, "infinity"}
  defp parse_cache_ttl_input(_), do: :ignore

  defp helpers_changeset(schema, params) do
    schema
    |> cast(params, [:name, :args, :code])
    |> validate_required([:name, :code])
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

  defp maybe_set_date_modified(changeset) do
    if get_field(changeset, :date_modified) do
      changeset
    else
      put_change(changeset, :date_modified, DateTime.utc_now() |> DateTime.truncate(:microsecond))
    end
  end
end

defimpl Phoenix.Param, for: Beacon.Content.Page do
  # we don't want to encode the leading slash
  def to_param(%{path: <<"/", rest::binary>>}), do: rest
end
