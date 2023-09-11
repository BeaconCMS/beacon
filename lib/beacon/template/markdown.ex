defmodule Beacon.Template.Markdown do
  @moduledoc """
  GitHub Flavored Markdown

  Use https://github.com/leandrocp/mdex to convert Markdown to HTML
  """

  # TODO: implement a markdown format that is aware of Phoenix features like link attrs and assigns

  @spec convert_to_html(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def convert_to_html(template, _metadata) do
    template = MDEx.to_html(template, extension: [table: true, autolink: true, tasklist: true], parse: [smart: true], render: [unsafe_: true])
    {:cont, template}
  rescue
    _error ->
      {:halt, %{message: "failed to convert markdown to html"}}
  end
end
