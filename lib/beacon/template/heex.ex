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
  # https://github.com/phoenixframework/phoenix_live_view/blob/fb111738d56745f37338867b9faea86eb9baa6e1/lib/phoenix_live_view/test/live_view_test.ex#L452
  def render_component(site, template, assigns, opts \\ []) when is_atom(site) and is_binary(template) and is_map(assigns) and is_list(opts) do
    endpoint = Beacon.Config.fetch!(site).endpoint
    socket = %Phoenix.LiveView.Socket{endpoint: endpoint, router: opts[:router]}

    assigns =
      assigns
      |> Map.new()
      |> Map.put_new(:__changed__, %{})

    {rendered, _} =
      "nofile"
      |> compile_heex_template!(template)
      |> Code.eval_quoted([assigns: assigns], BeaconWeb.PageLive.make_env())

    rendered_to_diff_string(rendered, socket)
  end

  defp rendered_to_diff_string(rendered, socket) do
    {_, diff, _} = Phoenix.LiveView.Diff.render(socket, rendered, Phoenix.LiveView.Diff.new_components())
    diff |> Phoenix.LiveView.Diff.to_iodata() |> IO.iodata_to_binary()
  end
end
