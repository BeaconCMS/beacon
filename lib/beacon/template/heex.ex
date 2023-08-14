defmodule Beacon.Template.HEEx do
  @moduledoc """
  Handle loading and compilation of HEEx templates.
  """

  import Beacon.Template, only: [is_ast: 1]
  require Logger

  @doc """
  Check if the template is safe.

  Perform the check using https://github.com/TheFirstAvenger/safe_code
  """
  @spec safe_code_check(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.t()} | {:halt, Exception.t()}
  def safe_code_check(template, _metadata) when is_binary(template) do
    # TODO: enable safe code when it's ready to parse complex templates
    # SafeCode.Validator.validate!(template, extra_function_validators: Beacon.Loader.SafeCodeImpl)
    {:cont, template}
  rescue
    exception ->
      {:halt, exception}
  end

  @doc """
  Compile `template` returning its AST.
  """
  @spec compile(Beacon.Template.t(), Beacon.Template.LoadMetadata.t()) :: {:cont, Beacon.Template.ast()} | {:halt, Exception.t()}
  def compile(template, metadata) when is_binary(template) do
    file = "site-#{metadata.site}-page-#{metadata.path}"
    ast = compile_heex_template!(file, template)
    # :cont so others can reuse this step
    {:cont, ast}
  rescue
    exception ->
      {:halt, exception}
  end

  @doc """
  Compile `template` AST to generate a `%Phoenix.LiveView.Rendered{}` struct.
  """
  @spec eval_ast(Beacon.Template.t(), Beacon.Template.RenderMetadata.t()) :: {:halt, Phoenix.LiveView.Rendered.t()}
  def eval_ast(template, metadata) when is_ast(template) do
    %{path: path, assigns: assigns, env: env} = metadata

    assigns = Phoenix.Component.assign(assigns, :beacon_path_params, path_params(path, assigns.__live_path__))

    functions = [
      {assigns.__beacon_page_module__, [dynamic_helper: 2]},
      {assigns.__beacon_component_module__, [my_component: 2]}
      | env.functions
    ]

    env = %{env | functions: functions}

    rendered =
      case Code.eval_quoted(template, [assigns: assigns], env) do
        {%Phoenix.LiveView.Rendered{} = rendered, _bindings} -> rendered
        {[%Phoenix.LiveView.Rendered{} = rendered], _bindings} -> rendered
      end

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
    EEx.compile_string(template,
      engine: Phoenix.LiveView.TagEngine,
      line: 1,
      file: file,
      caller: __ENV__,
      source: template,
      trim: true,
      tag_handler: Phoenix.LiveView.HTMLEngine
    )
  end
end
