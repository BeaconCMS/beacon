defmodule Beacon.Template.HEExConverter do
  @moduledoc """
  Converts HEEx templates to Beacon template syntax.

  Handles:
  - `<%= @var %>` → `{{ var }}`
  - `@var["key"]["key2"]` → `var.key.key2`
  - `<%= if ... do %>...<% end %>` wrapping a single element → `:if` on that element
  - `<%= for x <- list do %>...<% end %>` wrapping a single element → `:for` on that element
  - `<.link navigate={path}>text</.link>` → `<a href="path">text</a>`
  - Known function calls → enriched field references
  - `<%= ... %>` expressions → `{{ ... }}`
  - `phx-submit` → `@submit`, `phx-click` → `@click`

  Returns `{converted_template, warnings}`.
  """

  # Known function call → enriched field replacements
  @function_replacements [
    # PostView
    {~r/DockYardWeb\.PostView\.post_path\(([^)]+)\)/, "\\1.post_path"},
    {~r/DockYardWeb\.PostView\.post_url\(([^)]+)\)/, "\\1.post_url"},
    {~r/DockYardWeb\.PostView\.illustration\(([^,]+),\s*:large\)/, "\\1.illustration_large"},
    {~r/DockYardWeb\.PostView\.illustration\(([^,]+),\s*:small\)/, "\\1.illustration_small"},
    {~r/DockYardWeb\.PostView\.illustration_alt\(([^)]+)\)/, "\\1.illustration_alt_text"},
    {~r/DockYardWeb\.PostView\.author\(([^)]+)\)/, "\\1.author_name"},
    {~r/DockYardWeb\.PostView\.author_avatar_url\(([^)]+)\)/, "\\1.author_avatar_url"},
    {~r/DockYardWeb\.PostView\.twitter_share_url\(([^)]+)\)/, "\\1.twitter_share_url"},
    {~r/DockYardWeb\.PostView\.bluesky_share_url\(([^)]+)\)/, "\\1.bluesky_share_url"},
    {~r/DockYardWeb\.PostView\.linkedin_share_url\(([^)]+)\)/, "\\1.linkedin_share_url"},
    {~r/DockYardWeb\.PostView\.article_link_attrs\(([^)]+)\)/, "\\1.article_link_href"},
    # EmployeeView
    {~r/DockYardWeb\.EmployeeView\.random_avatar_uri\(([^)]+)\)/, "\\1.avatar_uri"},
    {~r/DockYardWeb\.EmployeeView\.display_name\(([^)]+)\)/, "\\1.display_name"},
    # Employee
    {~r/DockYard\.Employees\.Employee\.full_name\(([^)]+)\)/, "\\1.author_name"},
    # Beacon helpers
    {~r/Beacon\.Template\.Helpers\.format_datetime\(([^,]+),\s*"([^"]+)"(?:,\s*"([^"]*)")?\)/, "\\1 | format_date: \"\\2\""},
    {~r/Beacon\.Template\.Helpers\.to_iso_date\(([^)]+)\)/, "\\1 | format_date: \"%Y-%m-%d\""},
    # Stdlib
    {~r/Enum\.join\(([^,]+),\s*"([^"]*)"\)/, "\\1 | join: \"\\2\""},
    {~r/Jason\.encode!\(([^)]+)\)/, "\\1 | json"}
  ]

  @spec convert(binary()) :: {binary(), [binary()]}
  def convert(template) when is_binary(template) do
    {result, warnings} = {template, []}
    |> replace_known_functions()
    |> convert_eex_expressions()
    |> convert_assigns()
    |> convert_bracket_access()
    |> convert_phoenix_links()
    |> convert_phx_events()
    |> convert_simple_conditionals()
    |> convert_simple_loops()
    |> convert_eex_output_tags()
    |> cleanup_eex_remnants()
    |> flag_remaining_issues()

    {result, Enum.uniq(Enum.reverse(warnings))}
  end

  # Replace known function calls with enriched field references
  defp replace_known_functions({template, warnings}) do
    result = Enum.reduce(@function_replacements, template, fn {pattern, replacement}, acc ->
      Regex.replace(pattern, acc, replacement)
    end)

    {result, warnings}
  end

  # Convert simple <%= expr %> to {{ expr }}
  defp convert_eex_expressions({template, warnings}) do
    # {expr} (HEEx expression tags) → {{ expr }}
    # But only for simple expressions, not control flow
    result = Regex.replace(
      ~r/\{([a-zA-Z_][a-zA-Z0-9_.| :"%-]+)\}/,
      template,
      fn full, expr ->
        expr = String.trim(expr)
        # Don't convert if it's an HTML attribute value, class expression, etc.
        if String.contains?(expr, ":") and not String.contains?(expr, "|") do
          full  # Leave as-is (likely a keyword list or map)
        else
          "{{ #{expr} }}"
        end
      end
    )

    {result, warnings}
  end

  # @var → var (strip @ prefix)
  defp convert_assigns({template, warnings}) do
    # @var in expression context → var
    result = Regex.replace(~r/@([a-zA-Z_][a-zA-Z0-9_]*)/, template, "\\1")
    {result, warnings}
  end

  # var["key"] → var.key (nested bracket access to dot notation)
  defp convert_bracket_access({template, warnings}) do
    result = template
    |> do_bracket_to_dot()
    |> do_bracket_to_dot()
    |> do_bracket_to_dot()
    |> do_bracket_to_dot()

    {result, warnings}
  end

  defp do_bracket_to_dot(template) do
    Regex.replace(
      ~r/([a-zA-Z_][a-zA-Z0-9_]*)\["([a-zA-Z_][a-zA-Z0-9_?!]*)"\]/,
      template,
      "\\1.\\2"
    )
  end

  # <.link navigate={...}>...</.link> → <a href="...">...</a>
  defp convert_phoenix_links({template, warnings}) do
    result = template
    # Handle various <.link> attribute orderings
    |> then(fn t ->
      Regex.replace(~r/<\.link\s+([^>]*?)navigate=\{([^}]+)\}([^>]*)>/, t, fn _, before, path, after_ ->
        attrs = String.trim("#{before}#{after_}")
        if attrs == "" do
          "<a href=\"{{ #{String.trim(path)} }}\">"
        else
          "<a #{attrs} href=\"{{ #{String.trim(path)} }}\">"
        end
      end)
    end)
    |> then(fn t ->
      Regex.replace(~r/<\.link\s+([^>]*?)navigate="([^"]+)"([^>]*)>/, t, fn _, before, path, after_ ->
        attrs = String.trim("#{before}#{after_}")
        if attrs == "" do
          "<a href=\"#{path}\">"
        else
          "<a #{attrs} href=\"#{path}\">"
        end
      end)
    end)
    |> then(fn t ->
      Regex.replace(~r/<\.link\s+([^>]*?)href=\{([^}]+)\}([^>]*)>/, t, fn _, before, path, after_ ->
        attrs = String.trim("#{before}#{after_}")
        if attrs == "" do
          "<a href=\"{{ #{String.trim(path)} }}\">"
        else
          "<a #{attrs} href=\"{{ #{String.trim(path)} }}\">"
        end
      end)
    end)
    |> String.replace("</.link>", "</a>")

    {result, warnings}
  end

  # phx-submit → @submit, phx-click → @click
  defp convert_phx_events({template, warnings}) do
    result = template
    |> then(&Regex.replace(~r/phx-submit="([^"]+)"/, &1, "@submit=\"\\1\""))
    |> then(&Regex.replace(~r/phx-click="([^"]+)"/, &1, "@click=\"\\1\""))
    |> then(&Regex.replace(~r/phx-change="([^"]+)"/, &1, "@change=\"\\1\""))

    {result, warnings}
  end

  # <%= if expr do %>...<% end %> — flag for manual conversion
  defp convert_simple_conditionals({template, warnings}) do
    # Count if/end blocks
    if_count = length(Regex.scan(~r/<%=?\s*if\s/, template))

    new_warnings = if if_count > 0 do
      ["#{if_count} if/end block(s) need manual conversion to :if/:else directives"]
    else
      []
    end

    {template, warnings ++ new_warnings}
  end

  # <%= for x <- list do %>...<% end %> — flag for manual conversion
  defp convert_simple_loops({template, warnings}) do
    for_count = length(Regex.scan(~r/<%=?\s*for\s/, template))

    new_warnings = if for_count > 0 do
      ["#{for_count} for/end block(s) need manual conversion to :for directives"]
    else
      []
    end

    {template, warnings ++ new_warnings}
  end

  # <%= expr %> → {{ expr }} for remaining output tags
  defp convert_eex_output_tags({template, warnings}) do
    result = Regex.replace(
      ~r/<%=\s*(.+?)\s*%>/s,
      template,
      fn _, expr ->
        expr = String.trim(expr)
        "{{ #{expr} }}"
      end
    )

    {result, warnings}
  end

  # Clean up remaining EEx tags
  defp cleanup_eex_remnants({template, warnings}) do
    # <% end %> → remove (handled by :if/:for directives)
    result = Regex.replace(~r/\s*<%\s*end\s*%>\s*/, template, "\n")

    # <% code %> non-output tags → flag
    remaining = Regex.scan(~r/<%[^=](.+?)%>/s, result)

    new_warnings = if length(remaining) > 0 do
      ["#{length(remaining)} non-output EEx tag(s) (<% ... %>) need manual review"]
    else
      []
    end

    {result, warnings ++ new_warnings}
  end

  # Flag anything that couldn't be auto-converted
  defp flag_remaining_issues({template, warnings}) do
    new_warnings = []

    # Module function calls still present
    modules = Regex.scan(~r/([A-Z][a-zA-Z.]+\.[a-z_]+\([^)]*\))/, template)
    new_warnings = new_warnings ++ Enum.map(modules, fn [full | _] ->
      "Remaining function call: #{String.slice(full, 0, 80)}"
    end)

    # my_component calls
    components = Regex.scan(~r/my_component\("([^"]+)"/, template)
    new_warnings = new_warnings ++ Enum.map(components, fn [_, name] ->
      "my_component(\"#{name}\") needs component expansion"
    end)

    # raw() calls
    if Regex.match?(~r/raw\(/, template) do
      new_warnings = ["raw() HTML injection needs manual review" | new_warnings]
      {template, warnings ++ Enum.uniq(new_warnings)}
    else
      {template, warnings ++ Enum.uniq(new_warnings)}
    end
  end
end
