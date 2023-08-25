defmodule Beacon.Template.HEEx do
  @moduledoc """
  Handle loading and compilation of HEEx templates.
  """

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

  @doc false
  def compile_heex_template!(file, template) do
    EEx.compile_string(template,
      engine: Phoenix.LiveView.TagEngine,
      line: 1,
      indentation: 0,
      file: file,
      caller: __ENV__,
      source: template,
      trim: true,
      tag_handler: Phoenix.LiveView.HTMLEngine
    )
  end

  @doc """
  Returns the rendered HTML of a HEEx `template`

  ## Example

      iex> Beacon.Template.HEEx.render_component(:my_site, ~S|<.link patch="/contact" replace={true}><%= @text %></.link>|, %{text: "Book Meeting"})
      "<a href=\"/contact\" data-phx-link=\"patch\" data-phx-link-state=\"replace\">Book Meeting</a>"

  """
  def render_component(site, template, assigns, opts \\ []) when is_atom(site) and is_binary(template) and is_map(assigns) and is_list(opts) do
    assigns =
      assigns
      |> Map.new()
      |> Map.put_new(:__changed__, %{})

    env = BeaconWeb.PageLive.make_env()

    functions = [
      {Beacon.Loader.component_module_for_site(:my_site), [my_component: 2]}
      | env.functions
    ]

    env = %{env | functions: functions}

    {rendered, _} =
      "nofile"
      |> compile_heex_template!(template)
      |> Code.eval_quoted([assigns: assigns], env)

    rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
  end
end
