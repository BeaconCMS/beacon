defmodule Beacon.Lifecycle.Template do
  import Beacon.Lifecycle

  @doc """
  Load a `page` template using the registered format used on the `page`.

  This stage runs after fetching the page from the database and before storing the template into ETS.
  """
  @spec load_template(Beacon.Pages.Page.t()) :: Beacon.Template.t()
  def load_template(page) do
    case fetch_steps!(page.site, :load_template, page.format) do
      nil ->
        raise_missing_template_format(page.format)

      {_, steps} ->
        metadata = %Beacon.Template.LoadMetadata{site: page.site, path: page.path}
        execute_steps(:load_template, steps, page.template, metadata)
    end
  end

  @doc """
  Render a `page` template using the registered format used on the `page`.

  This stage runs in the render callback of the LiveView responsible for displaying the page.
  """
  def render_template(site, template, format, opts) do
    case fetch_steps!(site, :render_template, format) do
      nil ->
        raise_missing_template_format(format)

      {_, steps} ->
        metadata = build_metadata(site, opts)

        :render_template
        |> execute_steps(steps, template, metadata)
        |> check_rendered!(format)
    end
  end

  @doc false
  defp build_metadata(site, opts) do
    path = Keyword.fetch!(opts, :path)
    assigns = Keyword.fetch!(opts, :assigns)
    env = Keyword.fetch!(opts, :env)

    %Beacon.Template.RenderMetadata{site: site, path: path, assigns: assigns, env: env}
  end

  defp raise_missing_template_format(format) do
    raise Beacon.LoaderError, """
    expected a template registered for the format #{format}, but none was found.

    Make sure that format is properly registered at `:template_formats` in the site config,
    and `:load_template` and `:render_template` steps are defined.

    See `Beacon.Config` for more info.

    """
  end

  # https://github.com/phoenixframework/phoenix_live_view/blob/27ae991d613ec163f45fc5bfc857e3a66c426af6/lib/phoenix_live_view/utils.ex#L243
  defp check_rendered!(%Phoenix.LiveView.Rendered{} = rendered, _format), do: rendered

  defp check_rendered!(other, format) do
    raise Beacon.LoaderError, """
    expected the stage render_template of format #{format} to return a %Phoenix.LiveView.Rendered{} struct

    Got:

        #{inspect(other)}

    """
  end
end
