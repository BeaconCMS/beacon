defmodule Beacon.Template.HEEx do
  @moduledoc """
  Handle loading and compilation of HEEx templates.
  """

  @doc """
  Check if the template is safe.

  Perform the check using https://github.com/TheFirstAvenger/safe_code
  """
  @spec safe_code_check(String.t()) :: {:ok, String.t()} | {:error, Exception.t()}
  def safe_code_check(template) when is_binary(template) do
    # TODO: enable safe code when it's ready to parse complex templates
    # SafeCode.Validator.validate!(template, extra_function_validators: Beacon.Loader.SafeCodeImpl)
    {:ok, template}
  rescue
    exception ->
      {:error, exception}
  end

  @doc """
  Compile `template` returning its AST.
  """
  @spec compile(Beacon.Types.Site.t(), String.t(), String.t()) :: {:ok, Beacon.Template.ast()} | {:error, Exception.t()}
  def compile(site, path, template, file \\ nil) when is_atom(site) and is_binary(path) and is_binary(template) do
    file = if file, do: file, else: "site-#{site}-path-#{path}"
    compile_template(file, template)
  end

  def compile!(site, path, template, file \\ nil) when is_atom(site) and is_binary(path) and is_binary(template) do
    case compile(site, path, template, file) do
      {:ok, ast} -> ast
      {:error, exception} -> raise exception
    end
  end

  defp compile_template(file, template) do
    opts =
      [
        engine: Phoenix.LiveView.TagEngine,
        line: 1,
        indentation: 0,
        file: file,
        caller: __ENV__,
        source: template,
        trim: true,
        tag_handler: Phoenix.LiveView.HTMLEngine
      ]

    {:ok, EEx.compile_string(template, opts)}
  rescue
    error -> {:error, error}
  end

  @doc """
  Renders the HEEx `template` with `assigns`.

  > #### Use only to render isolated templates {: .warning}
  >
  > This function should not be used to render Page Templates,
  > its purpose is only to render isolated pieces of templates.

  ## Example

      iex> Beacon.Template.HEEx.render(:my_site, ~S|<.link patch="/contact" replace={true}><%= @text %></.link>|, %{text: "Book Meeting"})
      "<a href=\"/contact\" data-phx-link=\"patch\" data-phx-link-state=\"replace\">Book Meeting</a>"

  """
  @spec render(Beacon.Types.Site.t(), String.t(), map()) :: String.t()
  def render(site, template, assigns \\ %{}) when is_atom(site) and is_binary(template) and is_map(assigns) do
    assigns =
      assigns
      |> Map.new()
      |> Map.put_new(:__changed__, %{})

    env = BeaconWeb.PageLive.make_env()

    functions = [
      {Beacon.Loader.Components.module_name(site), [my_component: 2]}
      | env.functions
    ]

    env = %{env | functions: functions}
    {:ok, ast} = compile(site, "", template)
    {rendered, _} = Code.eval_quoted(ast, [assigns: assigns], env)

    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
