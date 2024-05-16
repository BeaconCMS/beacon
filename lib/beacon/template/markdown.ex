defmodule Beacon.Template.Markdown do
  @moduledoc """
  GitHub Flavored Markdown

  Use https://github.com/leandrocp/mdex to convert Markdown to HTML
  """

  # TODO: implement a markdown format that is aware of Phoenix features like link attrs and assigns

  @doc """
  Convert a markdown `template` into HTML using [mdex](https://hex.pm/packages/mdex)

  ## Options

    * `:syntax_highlight_theme` (default `"onedark"`) - see https://hexdocs.pm/mdex/MDEx.html#to_html/2 for more info.

  """
  @spec convert_to_html(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def convert_to_html(template, _metadata, opts \\ []) do
    syntax_highlight_theme = Keyword.get(opts, :syntax_highlight_theme, "onedark")

    template =
      MDEx.to_html(template,
        extension: [
          strikethrough: true,
          tagfilter: false,
          table: true,
          autolink: true,
          tasklist: true,
          superscript: true,
          description_lists: true
        ],
        parse: [smart: true],
        render: [
          hardbreaks: false,
          unsafe_: true
        ],
        features: [
          syntax_highlight_theme: syntax_highlight_theme
        ]
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
