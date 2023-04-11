defmodule Beacon.Lifecycle do
  @moduledoc """
  Beacon is open for extensibility by allowing users to inject custom steps into its internal lifecycle.

  You can add or overwrite those steps in `t:Beacon.Config.lifecycle/0`.

  Each one of these functions will be called in specific places inside Beacon's lifecycle,
  executing the steps defined in the site config.

  See each function doc for more info and also `Beacon.Config`.
  """

  @doc """
  Load a `page` template using the registered format used on the `page`.

  This stage runs after fetching the page from the database and before storing the template into ETS.
  """
  @spec load_template(Beacon.Pages.Page.t()) :: Beacon.Template.t()
  def load_template(page) do
    config = Beacon.Config.fetch!(page.site)

    {_, steps} =
      config.lifecycle
      |> Keyword.fetch!(:load_template)
      |> Enum.find(fn {format, _} -> format == page.format end) || raise_missing_template_format(page.format)

    do_load_template(page, steps)
  end

  @doc false
  def do_load_template(page, steps) do
    metadata = %Beacon.Template.LoadMetadata{site: page.site, path: page.path}
    execute_steps(:load_template, steps, page.template, metadata)
  end

  @doc """
  Render a `page` template using the registered format used on the `page`.

  This stage runs in the render callback of the LiveView responsible for displaying the page.
  """
  def render_template(opts) do
    site = Keyword.fetch!(opts, :site)
    config = Beacon.Config.fetch!(site)
    format = Keyword.fetch!(opts, :format)

    {_, steps} =
      config.lifecycle
      |> Keyword.fetch!(:render_template)
      |> Enum.find(fn {format, _} -> format == format end) || raise_missing_template_format(format)

    do_render_template(opts, steps)
  end

  @doc false
  def do_render_template(opts, steps) do
    site = Keyword.fetch!(opts, :site)
    path = Keyword.fetch!(opts, :path)
    format = Keyword.fetch!(opts, :format)
    template = Keyword.fetch!(opts, :template)
    assigns = Keyword.fetch!(opts, :assigns)
    env = Keyword.fetch!(opts, :env)

    metadata = %Beacon.Template.RenderMetadata{site: site, path: path, assigns: assigns, env: env}

    :render_template
    |> execute_steps(steps, template, metadata)
    |> check_rendered!(format)
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

  @doc """
    TODO
  """
  @spec create_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def create_page(page) do
    # TODO execute_steps
    page
  end

  @doc """
    TODO
  """
  @spec publish_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def publish_page(page) do
    # TODO execute_steps
    page
  end

  defp execute_steps(stage, steps, template, metadata) do
    Enum.reduce_while(steps, template, fn
      {step, fun}, acc when is_function(fun, 1) ->
        reduce_step(step, fun.(acc))

      {step, fun}, acc when is_function(fun, 2) ->
        reduce_step(step, fun.(acc, metadata))
    end)
  rescue
    e ->
      message = """
      expected stage #{stage} to define steps returning one of the following:

              {:cont, resource}
              {:halt, resource}
              {:halt, exception}

      Got:

          #{inspect(e)}

      """

      reraise Beacon.LoaderError, [message: message], __STACKTRACE__
  end

  defp reduce_step(step, result) do
    case result do
      {:cont, _} = acc ->
        acc

      {:halt, %{__exception__: true} = e} = _acc ->
        raise Beacon.LoaderError, """
        step #{inspect(step)} halted with the following message:

        #{Exception.message(e)}

        """

      {:halt, _} = acc ->
        acc

      other ->
        raise Beacon.LoaderError, """
        expected step #{inspect(step)} to return one of the following:

            {:cont, resource}
            {:halt, resource}
            {:halt, exception}

        Got:

            #{inspect(other)}

        """
    end
  end
end
