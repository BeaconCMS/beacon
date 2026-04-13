defmodule Beacon.TemplateType.JsonLdResolver do
  @moduledoc """
  Resolves a template type's `json_ld_mapping` into a concrete JSON-LD map
  by substituting `{field}` references with actual values from the page.
  """

  @reference_regex ~r/\{([^}]+)\}/

  @doc """
  Resolves a JSON-LD mapping template into a concrete JSON-LD map.

  Reference syntax: `{name}` where `name` is looked up in this order:
  1. `fields[name]` — the page's template-type-defined fields
  2. `manifest[name]` — page manifest fields (title, path, description, etc.)
  3. Config values: `site_name`, `site_url`

  Nested field access: `{fields.author_name}` resolves `fields["author_name"]`.

  Returns `nil` if the mapping is empty.
  """
  @spec resolve(map(), map(), map(), Beacon.Config.t()) :: map() | nil
  def resolve(mapping, _fields, _manifest, _config) when map_size(mapping) == 0, do: nil

  def resolve(mapping, fields, manifest, config) do
    context = build_context(fields, manifest, config)
    resolve_value(mapping, context)
  end

  defp build_context(fields, manifest, config) do
    %{
      "fields" => stringify_keys(fields),
      "title" => manifest[:title],
      "path" => manifest[:path],
      "description" => manifest[:description],
      "canonical_url" => manifest[:canonical_url],
      "date_modified" => format_value(manifest[:date_modified]),
      "inserted_at" => format_value(manifest[:inserted_at]),
      "updated_at" => format_value(manifest[:updated_at]),
      "site_name" => config.site_name,
      "site_url" => safe_site_url(config)
    }
  end

  defp resolve_value(map, context) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, resolve_value(value, context)} end)
  end

  defp resolve_value(list, context) when is_list(list) do
    Enum.map(list, &resolve_value(&1, context))
  end

  defp resolve_value(str, context) when is_binary(str) do
    if String.contains?(str, "{") do
      Regex.replace(@reference_regex, str, fn _, ref ->
        to_string(resolve_reference(ref, context) || "")
      end)
    else
      str
    end
  end

  defp resolve_value(value, _context), do: value

  defp resolve_reference(ref, context) do
    ref
    |> String.split(".")
    |> Enum.reduce(context, fn
      _key, nil -> nil
      key, map when is_map(map) -> Map.get(map, key)
      _key, _ -> nil
    end)
  end

  defp format_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_value(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp format_value(value), do: value

  defp safe_site_url(config) do
    if config[:site] do
      try do
        Beacon.RuntimeRenderer.public_site_url(config.site)
      rescue
        _ -> ""
      end
    else
      ""
    end
  end

  defp stringify_keys(nil), do: %{}
  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
