defmodule Beacon.Template.Markdown do
  def load(page) do
    # template =
    #   page.template # markdown
    #   |> convert_to_html()
    #   |> inject_css_classes(@tailwind_classes_mapping)
    #   |> inject_table_container()
    #   |> DockYard.Blog.Highlighter.highlight()

    file = "site-#{page.site}-page-#{page.path}"
    compile_heex_template!(page.site, file, page.template)

    # STEPS load template
    # input: page or markup
    # :convert_to_html        (Beacon)
    # :inject_css_classes     (DY) <- attach
    # :inject_table_container (DY) <- attach
    # :apply_syntax_highlight (DY) <- attach
    # :compile_heex           (Beacon)
    # output: Macro.t | String.t
  end

  def render do
  end

  @doc false
  def compile_heex_template!(site, file, template) do
    Beacon.safe_code_heex_check!(site, template)

    if Code.ensure_loaded?(Phoenix.LiveView.TagEngine) do
      EEx.compile_string(template,
        engine: Phoenix.LiveView.TagEngine,
        line: 1,
        file: file,
        caller: __ENV__,
        source: template,
        trim: true,
        tag_handler: Phoenix.LiveView.HTMLEngine
      )
    else
      EEx.compile_string(template,
        engine: Phoenix.LiveView.HTMLEngine,
        line: 1,
        file: file,
        caller: __ENV__,
        source: template,
        trim: true
      )
    end
  end
end
