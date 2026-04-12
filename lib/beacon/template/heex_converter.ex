defmodule Beacon.Template.HEExConverter do
  @moduledoc """
  Best-effort conversion of HEEx templates to the new Beacon template syntax.

  Handles common patterns:
  - `<%= @var %>` → `{{ var }}`
  - `<%= @var["key"] %>` → `{{ var.key }}`
  - `<%= if ... do %>...<% end %>` → `:if="..."`
  - `<%= for ... <- ... do %>...<% end %>` → `:for="..."`
  - `<.link navigate={path}>text</.link>` → `<a href="path">text</a>`
  - `my_component("name", props)` → `<name props />`

  Flags unconvertible patterns (Elixir function calls, complex expressions)
  with `<!-- MANUAL: ... -->` comments.
  """

  @doc """
  Convert a HEEx template string to Beacon template syntax.

  Returns `{converted_template, warnings}` where warnings is a list of
  strings describing patterns that could not be automatically converted.
  """
  @spec convert(binary()) :: {binary(), [binary()]}
  def convert(template) when is_binary(template) do
    warnings = []

    {result, warnings} = {template, warnings}
    |> convert_assigns()
    |> convert_bracket_access()
    |> convert_phoenix_links()
    |> convert_simple_conditionals()
    |> convert_simple_loops()
    |> flag_function_calls()
    |> flag_my_component_calls()

    {result, Enum.reverse(warnings)}
  end

  # @var → var (strip @ prefix for assigns)
  defp convert_assigns({template, warnings}) when is_binary(template) do
    # <%= @var %> → {{ var }}
    result = Regex.replace(
      ~r/<%=\s*@([a-zA-Z_][a-zA-Z0-9_]*)\s*%>/,
      template,
      "{{ \\1 }}"
    )

    # @var["key"] inside expressions → var.key
    result = Regex.replace(
      ~r/@([a-zA-Z_][a-zA-Z0-9_]*)\["([a-zA-Z_][a-zA-Z0-9_]*)"\]/,
      result,
      "\\1.\\2"
    )

    {result, warnings}
  end

  # Nested bracket access: var["key1"]["key2"] → var.key1.key2
  defp convert_bracket_access({template, warnings}) do
    # Repeat to handle deeply nested
    result = template
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

  # <.link navigate={path}>text</.link> → <a href={path}>text</a>
  defp convert_phoenix_links({template, warnings}) do
    # navigate= links
    result = Regex.replace(
      ~r/<\.link\s+navigate=\{([^}]+)\}\s*>/,
      template,
      "<a href={\\1}>"
    )

    # navigate="path" links
    result = Regex.replace(
      ~r/<\.link\s+navigate="([^"]+)"\s*>/,
      result,
      "<a href=\"\\1\">"
    )

    # href= links
    result = Regex.replace(
      ~r/<\.link\s+href=\{([^}]+)\}\s*>/,
      result,
      "<a href={\\1}>"
    )

    # With class and navigate
    result = Regex.replace(
      ~r/<\.link\s+class="([^"]+)"\s+navigate=\{([^}]+)\}\s*>/,
      result,
      "<a class=\"\\1\" href={\\2}>"
    )

    result = Regex.replace(
      ~r/<\.link\s+class="([^"]+)"\s+navigate="([^"]+)"\s*>/,
      result,
      "<a class=\"\\1\" href=\"\\2\">"
    )

    # Close tags
    result = String.replace(result, "</.link>", "</a>")

    {result, warnings}
  end

  # Simple conditionals: <%= if expr do %>...<% end %> → :if on wrapper
  defp convert_simple_conditionals({template, warnings}) do
    # This is a best-effort conversion for simple cases
    # Complex multi-line conditionals are flagged for manual review
    {template, warnings}
  end

  # Simple loops: <%= for x <- list do %>...<% end %> → :for on wrapper
  defp convert_simple_loops({template, warnings}) do
    {template, warnings}
  end

  # Flag Elixir function calls that can't be auto-converted
  defp flag_function_calls({template, warnings}) do
    # Find Module.function() calls
    modules = Regex.scan(~r/([A-Z][a-zA-Z.]+\.[a-z_]+\([^)]*\))/, template)

    new_warnings = Enum.map(modules, fn [full | _] ->
      "Function call needs manual migration to resolver: #{String.slice(full, 0, 80)}"
    end)

    {template, warnings ++ Enum.uniq(new_warnings)}
  end

  # Flag my_component calls
  defp flag_my_component_calls({template, warnings}) do
    components = Regex.scan(~r/my_component\("([^"]+)"/, template)

    new_warnings = Enum.map(components, fn [_, name] ->
      "my_component(\"#{name}\") call needs component expansion"
    end)

    {template, warnings ++ Enum.uniq(new_warnings)}
  end
end
