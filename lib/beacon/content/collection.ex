defmodule Beacon.Content.Collection do
  @moduledoc """
  Defines a content collection for Beacon pages.

  A Collection is the primary organizational concept in Beacon. It defines
  "what kind of content am I making?" — the data contract, layout, SEO mappings,
  starter template, and URL pattern for a class of pages.

  ## Modes

    * `:managed` — Beacon stores each page as a separate content entry.
      Each blog post, landing page, etc. is a row in `beacon_pages`.

    * `:template` — Beacon stores a single template for dynamic routes.
      The consuming client provides data at render time (e.g., `/blog/:slug`
      renders from external data). Beacon doesn't store individual content items.

  ## Tiers

    * **Global** (`site: nil`) — Available to all sites.
    * **Site-specific** (`site: :my_site`) — Available only to that site.

  ## Field Definitions

  An array of maps defining the expected data fields:

      [
        %{"name" => "author_name", "type" => "string", "required" => true, "label" => "Author Name"},
        %{"name" => "published_date", "type" => "datetime", "required" => true},
        %{"name" => "illustration", "type" => "url", "label" => "Featured Image"}
      ]

  Supported types: `string`, `text`, `integer`, `float`, `boolean`, `datetime`,
  `date`, `url`, `select`, `list`, `reference`.

  ## JSON-LD Mapping

  A declarative map with `{field}` references resolved at render time:

      %{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "headline" => "{title}",
        "datePublished" => "{fields.published_date}"
      }

  ## Meta Tag Mapping

  A list of meta tag maps with `{field}` references:

      [
        %{"property" => "og:type", "content" => "article"},
        %{"property" => "article:author", "content" => "{fields.author_name}"}
      ]
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  @valid_modes ~w(managed template)

  schema "beacon_collections" do
    field :site, Beacon.Types.Site
    field :name, :string
    field :slug, :string
    field :description, :string
    field :mode, :string, default: "managed"
    field :layout_id, :binary_id
    field :fields, {:array, :map}, default: []
    field :json_ld_mapping, :map, default: %{}
    field :meta_tag_mapping, {:array, :map}, default: []
    field :starter_template, :string
    field :path_prefix, :string
    field :path_pattern, :string
    field :icon, :string
    field :sort_order, :integer, default: 0

    timestamps()
  end

  @supported_field_types ~w(string text integer float boolean datetime date url select list reference)

  @doc false
  def changeset(collection \\ %__MODULE__{}, attrs) do
    collection
    |> cast(attrs, [
      :site, :name, :slug, :description, :mode, :layout_id,
      :fields, :json_ld_mapping, :meta_tag_mapping,
      :starter_template, :path_prefix, :path_pattern,
      :icon, :sort_order
    ])
    |> validate_required([:name, :slug, :mode])
    |> validate_inclusion(:mode, @valid_modes, message: "must be one of: #{Enum.join(@valid_modes, ", ")}")
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/, message: "must be lowercase alphanumeric with hyphens")
    |> unique_constraint([:site, :slug])
    |> validate_field_definitions()
  end

  def valid_modes, do: @valid_modes

  defp validate_field_definitions(changeset) do
    validate_change(changeset, :fields, fn :fields, definitions ->
      errors =
        definitions
        |> Enum.with_index()
        |> Enum.flat_map(fn {def_map, idx} ->
          cond do
            not is_map(def_map) ->
              [{:fields, "item #{idx} must be a map"}]

            not is_binary(def_map["name"]) or def_map["name"] == "" ->
              [{:fields, "item #{idx} missing 'name'"}]

            not is_binary(def_map["type"]) or def_map["type"] not in @supported_field_types ->
              [{:fields, "item #{idx} has invalid type '#{def_map["type"]}'. Supported: #{Enum.join(@supported_field_types, ", ")}"}]

            true ->
              []
          end
        end)

      names = Enum.map(definitions, & &1["name"])
      dupes = names -- Enum.uniq(names)

      if dupes != [] do
        [{:fields, "duplicate field names: #{Enum.join(Enum.uniq(dupes), ", ")}"} | errors]
      else
        errors
      end
    end)
  end
end
