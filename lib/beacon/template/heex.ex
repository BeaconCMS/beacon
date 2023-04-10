defmodule Beacon.Template.HEEx do
  @moduledoc """
  TODO
  """

  import Beacon.Template, only: [is_ast: 1]

  @spec safe_code_check(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def safe_code_check(template, metadata) when is_binary(template) do
    # TODO: enable safe code when it's ready to parse complex templates
    # SafeCode.Validator.validate!(template, extra_function_validators: Beacon.Loader.SafeCodeImpl)
    {:cont, template}
  rescue
    e ->
      message = """
      unsafe template for path #{metadata.path}

      Got:

          #{inspect(e)}

      """

      {:halt, %Beacon.LoaderError{message: message}}
  end

  @spec compile(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:halt, Beacon.Template.ast()}
  def compile(template, metadata) when is_binary(template) do
    file = "site-#{metadata.site}-page-#{metadata.path}"
    ast = compile_heex_template!(file, template)
    {:halt, ast}
  rescue
    e ->
      message = """
      failed to compile heex template for path #{metadata.path}

      Got:

          #{inspect(e)}

      """

      {:halt, %Beacon.LoaderError{message: message}}
  end

  @spec eval_ast(Beacon.Template.t(), Beacon.Template.RenderMetadata.t()) :: {:halt, Phoenix.LiveView.Rendered.t()}
  def eval_ast(template, metadata) when is_ast(template) do
    %{path: path, assigns: assigns, env: env} = metadata

    assigns = Phoenix.Component.assign(assigns, :beacon_path_params, path_params(path, assigns.__live_path__))

    functions = [
      {assigns.__beacon_page_module__, [dynamic_helper: 2]},
      {assigns.__beacon_component_module__, [my_component: 2]}
      | env.functions
    ]

    opts =
      env
      |> Map.from_struct()
      |> Keyword.new()
      |> Keyword.put(:functions, functions)

    {rendered, _bindings} = Code.eval_quoted(template, [assigns: assigns], opts)

    {:halt, rendered}
  end

  defp path_params(page_path, path_info) do
    page_path = String.split(page_path, "/")

    Enum.zip_reduce(page_path, path_info, %{}, fn
      ":" <> segment, value, acc ->
        Map.put(acc, segment, value)

      "*" <> segment, value, acc ->
        position = Enum.find_index(path_info, &(&1 == value))
        Map.put(acc, segment, Enum.drop(path_info, position))

      _, _, acc ->
        acc
    end)
  end

  @doc false
  def compile_heex_template!(file, template) do
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
