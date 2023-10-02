defmodule Beacon.Template.Markdown do
  @moduledoc """
  GitHub Flavored Markdown

  Use https://github.com/leandrocp/mdex to convert Markdown to HTML
  """

  # TODO: implement a markdown format that is aware of Phoenix features like link attrs and assigns

  @spec convert_to_html(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def convert_to_html(template, _metadata) do
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
          hardbreaks: true,
          unsafe_: true
        ],
        features: [
          syntax_highlight_theme: "onedark"
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
