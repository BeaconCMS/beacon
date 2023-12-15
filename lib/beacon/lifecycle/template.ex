defmodule Beacon.Lifecycle.Template do
  @moduledoc false

  alias Beacon.Lifecycle
  @behaviour Beacon.Lifecycle

  @impl Lifecycle
  def put_metadata(%Lifecycle{name: :load_template} = lifecycle, site_config, context) do
    metadata = %Beacon.Template.LoadMetadata{site: site_config.site, path: context.path}
    %{lifecycle | metadata: metadata}
  end

  def put_metadata(%Lifecycle{name: :render_template} = lifecycle, site_config, context) do
    path = Keyword.fetch!(context, :path)
    assigns = Keyword.fetch!(context, :assigns)
    env = Keyword.fetch!(context, :env)

    metadata = %Beacon.Template.RenderMetadata{site: site_config.site, path: path, assigns: assigns, env: env}
    %{lifecycle | metadata: metadata}
  end

  @impl Lifecycle
  def validate_input!(%Lifecycle{name: name} = lifecycle, site_config, sub_key) do
    allowed_formats = site_config.template_formats
    format_allowed? = Keyword.has_key?(allowed_formats, sub_key)

    format_configured? =
      site_config.lifecycle
      |> Keyword.fetch!(name)
      |> Keyword.has_key?(sub_key)

    if format_allowed? && format_configured? do
      lifecycle
    else
      raise Beacon.LoaderError, """
      For site: #{site_config.site}
      #{format_allowed_error_text(format_allowed?, sub_key, allowed_formats)}

      #{unconfigured_error_text(format_configured?, sub_key)}

      See `Beacon.Config` for more info.

      """
    end
  end

  defp format_allowed_error_text(false, format, allowed_formats) do
    """
    Expected to find format: #{format} in Beacon.Config.template_formats. Allowed formats are: #{inspect(allowed_formats)}.
    Make sure that format is properly registered at `:template_formats` in the site config.
    """
  end

  defp format_allowed_error_text(_, _, _), do: ""

  defp unconfigured_error_text(false, format) do
    """
    Expected to find steps configured for format: #{format} in
    Beacon.Config.sites.load_template
    Beacon.Config.sites.render_template
    """
  end

  defp unconfigured_error_text(_, _), do: ""

  @impl Lifecycle
  def validate_output!(%Lifecycle{name: :load_template} = lifecycle, _site, _type), do: lifecycle
  def validate_output!(%Lifecycle{name: :render_template, output: %Phoenix.LiveView.Rendered{}} = lifecycle, _site, _type), do: lifecycle
  # https://github.com/phoenixframework/phoenix_live_view/blob/27ae991d613ec163f45fc5bfc857e3a66c426af6/lib/phoenix_live_view/utils.ex#L243

  def validate_output!(lifecycle, _site, _type) do
    raise Beacon.LoaderError, """
    expected output to be a %Phoenix.LiveView.Rendered{} struct

    Got:

      #{inspect(lifecycle.output)}

    """
  end

  @doc """
  Load a `page` template using the registered format used on the `page`.
  This stage runs after fetching the page from the database and before storing the template into ETS.
  """
  @spec load_template(Beacon.Content.Page.t()) :: Beacon.Template.t()
  def load_template(page) do
    lifecycle = Lifecycle.execute(__MODULE__, page.site, :load_template, page.template, sub_key: page.format, context: %{path: page.path})
    lifecycle.output
  end

  @doc """
  Render a `page` template using the registered format used on the `page`.

  ## Notes

    - This stage runs in the render callback of the LiveView responsible for displaying the page.
    - It will load and compile the page module if it was not loaded yet.

  """
  @spec render_template(Beacon.Content.Page.t(), module(), map(), Macro.Env.t()) :: Beacon.Template.t()
  def render_template(page, page_module, assigns, env) do
    template =
      case Beacon.Template.render(page_module, assigns) do
        %Phoenix.LiveView.Rendered{} = rendered -> rendered
        :not_loaded -> Beacon.Loader.load_page_template(page, page_module, assigns)
      end

    context = [path: page.path, assigns: assigns, env: env]
    lifecycle = Lifecycle.execute(__MODULE__, page.site, :render_template, template, sub_key: page.format, context: context)
    lifecycle.output
  end
end
