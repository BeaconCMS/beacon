defmodule Beacon.CSS.ThemeParser do
  @moduledoc """
  Parses a Tailwind v4 JavaScript config file and extracts theme values
  as a JSON string compatible with the TailwindCompiler NIF.

  Only handles the `theme.extend` section. Supports string, number,
  and nested object values. Ignores JavaScript expressions, functions,
  and requires.
  """

  @doc """
  Parse a Tailwind config JS file and return a JSON string of theme overrides.

  Returns `nil` if the file doesn't exist or can't be parsed.
  """
  def parse_file(path) when is_binary(path) do
    if File.exists?(path) do
      path |> File.read!() |> parse_js_config()
    end
  end

  @doc """
  Parse a Tailwind config JS string and return a JSON string of theme overrides.
  """
  def parse_js_config(js) when is_binary(js) do
    theme = %{}

    theme =
      theme
      |> maybe_put("colors", extract_section(js, "colors"))
      |> maybe_put("spacing", extract_section(js, "spacing"))
      |> maybe_put("fontFamily", extract_section(js, "fontFamily"))
      |> maybe_put("fontSize", extract_section(js, "fontSize"))
      |> maybe_put("fontWeight", extract_section(js, "fontWeight"))
      |> maybe_put("letterSpacing", extract_section(js, "letterSpacing"))
      |> maybe_put("lineHeight", extract_section(js, "lineHeight"))
      |> maybe_put("borderRadius", extract_section(js, "borderRadius"))
      |> maybe_put("maxWidth", extract_section(js, "maxWidth"))
      |> maybe_put("height", extract_section(js, "height"))
      |> maybe_put("boxShadow", extract_section(js, "boxShadow"))
      |> maybe_put("transitionDuration", extract_section(js, "transitionDuration"))
      |> maybe_put("transitionProperty", extract_section(js, "transitionProperty"))
      |> maybe_put("gridTemplateColumns", extract_section(js, "gridTemplateColumns"))
      |> maybe_put("gridTemplateRows", extract_section(js, "gridTemplateRows"))
      |> maybe_put("aspectRatio", extract_section(js, "aspectRatio"))

    # Post-process fontSize: split array values into size + line-height
    # v4 expects --text-3xl: 2rem and --text-3xl--line-height: 2.5rem
    theme =
      case Map.get(theme, "fontSize") do
        nil ->
          theme

        font_sizes when is_map(font_sizes) ->
          {split_sizes, _} =
            Enum.reduce(font_sizes, {%{}, %{}}, fn {key, value}, {sizes, _} ->
              case String.split(value, ",", parts: 2) do
                [size, line_height] ->
                  {sizes |> Map.put(key, String.trim(size)) |> Map.put("#{key}--line-height", String.trim(line_height)), %{}}

                [_single] ->
                  {Map.put(sizes, key, value), %{}}
              end
            end)

          Map.put(theme, "fontSize", split_sizes)
      end

    if map_size(theme) > 0 do
      Jason.encode!(theme)
    end
  end

  # Extract a section like `colors: { ... }` from the JS config
  defp extract_section(js, section_name) do
    # Match: sectionName: { ... } (handling nested braces)
    case Regex.run(~r/#{section_name}\s*:\s*\{/s, js, return: :index) do
      [{start, len}] ->
        brace_start = start + len - 1
        content = extract_braced_content(js, brace_start)
        if content, do: parse_js_object(content)

      _ ->
        nil
    end
  end

  # Extract content between matched braces { ... }
  defp extract_braced_content(js, start) do
    js
    |> String.slice(start..-1//1)
    |> scan_braces(0, 0)
  end

  defp scan_braces(str, pos, depth) do
    if pos >= byte_size(str) do
      nil
    else
      char = String.at(str, pos)

      cond do
        char == "{" -> scan_braces(str, pos + 1, depth + 1)
        char == "}" and depth == 1 -> String.slice(str, 1..(pos - 1)//1)
        char == "}" -> scan_braces(str, pos + 1, depth - 1)
        true -> scan_braces(str, pos + 1, depth)
      end
    end
  end

  # Parse a JS object literal into an Elixir map
  # Handles: string keys, quoted/unquoted values, nested objects, arrays
  defp parse_js_object(content) when is_binary(content) do
    content
    |> String.trim()
    |> parse_pairs(%{})
  end

  defp parse_pairs("", acc), do: acc

  defp parse_pairs(content, acc) do
    content = String.trim(content)
    if content == "" or content == "," do
      acc
    else
      case parse_key_value(content) do
        {key, value, rest} ->
          acc = Map.put(acc, key, value)
          rest = rest |> String.trim_leading() |> String.trim_leading(",") |> String.trim()
          parse_pairs(rest, acc)

        nil ->
          acc
      end
    end
  end

  defp parse_key_value(content) do
    # Match key: 'quoted-key' or unquoted_key
    case Regex.run(~r/^(?:'([^']*)'|"([^"]*)"|([a-zA-Z0-9_-]+))\s*:\s*/s, content) do
      [full_match, key] ->
        key = if key == "", do: nil, else: key
        rest = String.slice(content, String.length(full_match)..-1//1)
        parse_value(key || extract_key(full_match), rest)

      [full_match, "", key] ->
        rest = String.slice(content, String.length(full_match)..-1//1)
        parse_value(key, rest)

      [full_match, "", "", key] ->
        rest = String.slice(content, String.length(full_match)..-1//1)
        parse_value(key, rest)

      _ ->
        # Skip unrecognized content up to next comma or end
        case String.split(content, ",", parts: 2) do
          [_, rest] -> parse_key_value(String.trim(rest))
          _ -> nil
        end
    end
  end

  defp extract_key(match) do
    match
    |> String.trim()
    |> String.trim_trailing(":")
    |> String.trim()
    |> String.trim("'")
    |> String.trim("\"")
  end

  defp parse_value(key, rest) do
    rest = String.trim(rest)

    cond do
      # Nested object
      String.starts_with?(rest, "{") ->
        inner = extract_braced_content(rest, 0)
        if inner do
          consumed = 1 + byte_size(inner) + 1
          remaining = String.slice(rest, consumed..-1//1)
          value = parse_js_object(inner)
          {key, flatten_nested_colors(value), remaining}
        end

      # Array value like ['Plus Jakarta Sans', 'sans-serif']
      String.starts_with?(rest, "[") ->
        case Regex.run(~r/^\[([^\]]*)\]/s, rest) do
          [full, inner] ->
            remaining = String.slice(rest, String.length(full)..-1//1)
            # Join array into a single string (for fontFamily)
            value =
              inner
              |> String.split(",")
              |> Enum.map(&(&1 |> String.trim() |> String.trim("'") |> String.trim("\"")))
              |> Enum.join(", ")

            {key, value, remaining}

          _ ->
            nil
        end

      # String value (single or double quoted)
      String.starts_with?(rest, "'") or String.starts_with?(rest, "\"") ->
        quote_char = String.at(rest, 0)
        case Regex.run(~r/^#{Regex.escape(quote_char)}([^#{Regex.escape(quote_char)}]*)#{Regex.escape(quote_char)}/s, rest) do
          [full, value] ->
            remaining = String.slice(rest, String.length(full)..-1//1)
            {key, value, remaining}

          _ ->
            nil
        end

      # var(...) expression
      String.starts_with?(rest, "var(") ->
        case Regex.run(~r/^var\([^)]*\)/s, rest) do
          [full] ->
            remaining = String.slice(rest, String.length(full)..-1//1)
            {key, full, remaining}

          _ ->
            nil
        end

      # Bare number
      Regex.match?(~r/^[0-9]/, rest) ->
        case Regex.run(~r/^([0-9.]+)/s, rest) do
          [full, value] ->
            remaining = String.slice(rest, String.length(full)..-1//1)
            {key, value, remaining}

          _ ->
            nil
        end

      true ->
        # Skip to next comma
        case String.split(rest, ",", parts: 2) do
          [_, remaining] -> {key, nil, remaining}
          _ -> nil
        end
    end
  end

  # Flatten nested color objects into flat keys for the theme
  # e.g., %{"gray" => %{"50" => "#F0F5F9"}} stays as-is (theme.parseJson handles nesting)
  defp flatten_nested_colors(value) when is_map(value), do: value
  defp flatten_nested_colors(value), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
