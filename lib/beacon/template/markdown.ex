defmodule Beacon.Template.Markdown do
  @moduledoc """
  GitHub Flavored Markdown

  Use https://github.com/github/cmark-gfm to convert Markdown to HTML
  """

  # TODO: implement a markdown format that is aware of Phoenix features like link attrs and assigns

  # TODO: replace cli with C or Rust lib
  @spec convert_to_html(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def convert_to_html(template, _metadata) do
    cmark_gfm_bin = find_cmark_gfm_bin!()

    random_file_name = Base.encode16(:crypto.strong_rand_bytes(12))
    random_file_path = Path.join(System.tmp_dir!(), random_file_name)
    File.write!(random_file_path, template)

    # credo:disable-for-next-line
    args = ~w(--unsafe --smart -e table -e autolink -e tasklist --to html) ++ [random_file_path]
    # credo:disable-for-next-line

    {output, exit_code} = System.cmd(cmark_gfm_bin, args, stderr_to_stdout: true)
    File.rm(random_file_path)

    if exit_code == 0 do
      {:cont, output}
    else
      message = """
      failed to convert markdown to html

      Got:

          exit code: #{exit_code}
          output: #{output}

      """

      {:halt, %Beacon.ParserError{message: message}}
    end
  end

  defp find_cmark_gfm_bin! do
    System.find_executable("cmark-gfm") || raise "here"
  end
end
