defmodule Beacon.Content.TemplateType do
  @moduledoc """
  Defines a content type schema for Beacon pages.

  A template type formalizes the data contract for a class of pages: what fields
  they expect, how those fields map to JSON-LD structured data, and how they map
  to meta tags.

  ## Tiers

    * **Global** (`site: nil`) — Available to all sites. Created by Beacon-level admins.
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

  schema "beacon_template_types" do
    field :site, Beacon.Types.Site
    field :name, :string
    field :slug, :string
    field :field_definitions, {:array, :map}, default: []
    field :json_ld_mapping, :map, default: %{}
    field :meta_tag_mapping, {:array, :map}, default: []

    timestamps()
  end

  @supported_field_types ~w(string text integer float boolean datetime date url select list reference)

  @doc false
  def changeset(template_type \\ %__MODULE__{}, attrs) do
    template_type
    |> cast(attrs, [:site, :name, :slug, :field_definitions, :json_ld_mapping, :meta_tag_mapping])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/, message: "must be lowercase alphanumeric with hyphens")
    |> unique_constraint([:site, :slug])
    |> validate_field_definitions()
  end

  defp validate_field_definitions(changeset) do
    validate_change(changeset, :field_definitions, fn :field_definitions, definitions ->
      errors =
        definitions
        |> Enum.with_index()
        |> Enum.flat_map(fn {def_map, idx} ->
          cond do
            not is_map(def_map) ->
              [{:field_definitions, "item #{idx} must be a map"}]

            not is_binary(def_map["name"]) or def_map["name"] == "" ->
              [{:field_definitions, "item #{idx} missing 'name'"}]

            not is_binary(def_map["type"]) or def_map["type"] not in @supported_field_types ->
              [{:field_definitions, "item #{idx} has invalid type '#{def_map["type"]}'. Supported: #{Enum.join(@supported_field_types, ", ")}"}]

            true ->
              []
          end
        end)

      # Check for duplicate names
      names = Enum.map(definitions, & &1["name"])
      dupes = names -- Enum.uniq(names)

      if dupes != [] do
        [{:field_definitions, "duplicate field names: #{Enum.join(Enum.uniq(dupes), ", ")}"} | errors]
      else
        errors
      end
    end)
  end
end
