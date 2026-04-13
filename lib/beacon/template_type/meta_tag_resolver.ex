defmodule Beacon.TemplateType.MetaTagResolver do
  @moduledoc """
  Resolves a template type's `meta_tag_mapping` into concrete meta tag maps
  by substituting `{field}` references with actual values from the page.
  """

  @reference_regex ~r/\{([^}]+)\}/

  @doc """
  Resolves a list of meta tag mapping templates into concrete meta tag maps.

  Same reference syntax as `Beacon.TemplateType.JsonLdResolver`.
  Returns an empty list if the mapping is empty.
  """
  @spec resolve([map()], map(), map(), Beacon.Config.t()) :: [map()]
  def resolve(mapping, _fields, _manifest, _config) when mapping == [] or is_nil(mapping), do: []

  def resolve(mapping, fields, manifest, config) when is_list(mapping) do
    context = build_context(fields, manifest, config)

    Enum.map(mapping, fn tag_map ->
      Map.new(tag_map, fn {key, value} ->
        {key, resolve_value(value, context)}
      end)
    end)
  end

  defp build_context(fields, manifest, config) do
    %{
      "fields" => stringify_keys(fields),
      "title" => manifest[:title],
      "path" => manifest[:path],
      "description" => manifest[:description],
      "canonical_url" => manifest[:canonical_url],
      "date_modified" => format_value(manifest[:date_modified]),
      "site_name" => config.site_name,
      "site_url" => safe_site_url(config)
    }
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
