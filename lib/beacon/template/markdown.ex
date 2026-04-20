defmodule Beacon.Template.Markdown do
  @moduledoc """
  GitHub Flavored Markdown

  Uses https://github.com/leandrocp/mdex to convert Markdown to HTML
  """

  # TODO: implement a markdown format that is aware of Phoenix features like link attrs and assigns

  @doc """
  Convert a markdown `template` into HTML using [mdex](https://hex.pm/packages/mdex)

  ## Options

    * `:syntax_highlight_theme` (default `"onedark"`) - see https://hexdocs.pm/mdex/MDEx.html#to_html/2 for more info.

  """
  @spec convert_to_html(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def convert_to_html(template, _metadata, _opts \\ []) do

    template =
      MDEx.to_html!(template,
        extension: [
          strikethrough: true,
          table: true,
          autolink: true,
          tasklist: true,
          superscript: true,
          footnotes: true,
          description_lists: true,
          multiline_block_quotes: true,
          shortcodes: true,
          underline: true
        ],
        parse: [
          relaxed_tasklist_matching: true,
          relaxed_autolinks: true
        ],
        render: [
          unsafe_: true
        ],
        syntax_highlight: [formatter: {:html_inline, theme: "onedark"}],
        sanitize: MDEx.Document.default_sanitize_options()
      )

    {:cont, template}
  rescue
    exception ->
      message = """
      failed to convert markdown to html

      Got:

        #{Exception.message(exception)}

      """

      {:halt, %Beacon.ParserError{message: message}}
  end
end
