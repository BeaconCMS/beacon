defmodule Beacon.Template.Markdown do
  @moduledoc """
  GitHub Flavored Markdown

  Use https://github.com/leandrocp/mdex to convert Markdown to HTML
  """

  # TODO: implement a markdown format that is aware of Phoenix features like link attrs and assigns

  @spec convert_to_html(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def convert_to_html(template, _metadata) do
    {:cont, MDEx.to_html(template)}
  end
end
