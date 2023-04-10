defmodule Beacon.Lifecycle do
  @moduledoc """
  Beacon is open for extensibility by allowing users to inject custom steps into its internal lifecycle.

  See each function doc for more info and `Beacon.Config` option `:lifecycle` to configure each one.

  """

  @doc """
  Load a `page` template into ETS.

  Between fetching the page from database and loading it into ETS,
  you can perform custom steps to transform the template, and these steps
  are configured by registering a `t:Beacon.Config.template_format/0` in `:lifecycle` option for `Beacon.Config`.
  """
  @spec load_template(Beacon.Pages.Page.t()) :: Beacon.Template.t()
  def load_template(page) do
    config = Beacon.Config.fetch!(page.site)
    template_formats = Keyword.fetch!(config.lifecycle, :template)
    do_load_template(page, template_formats)
  end

  @doc false
  def do_load_template(page, template_formats) do
    metadata = %Beacon.Template.LoadMetadata{site: page.site, path: page.path}

    page.format
    |> fetch_steps!(template_formats, :load)
    |> execute_steps(:load, page.template, metadata)
  end

  @doc """
  Render a `page` template, executed in the `render/2` callback.

  These steps are configured by registering a `t:Beacon.Config.template_format/0` in `t:Beacon.Config.lifecycle/0`.
  """
  def render_template(opts) do
    site = Keyword.fetch!(opts, :site)
    config = Beacon.Config.fetch!(site)
    template_formats = Keyword.fetch!(config.lifecycle, :template)
    do_render_template(opts, template_formats)
  end

  @doc false
  def do_render_template(opts, template_formats) do
    site = Keyword.fetch!(opts, :site)
    path = Keyword.fetch!(opts, :path)
    format = Keyword.fetch!(opts, :format)
    template = Keyword.fetch!(opts, :template)
    assigns = Keyword.fetch!(opts, :assigns)
    env = Keyword.fetch!(opts, :env)

    metadata = %Beacon.Template.RenderMetadata{site: site, path: path, assigns: assigns, env: env}

    format
    |> fetch_steps!(template_formats, :render)
    |> execute_steps(:render, template, metadata)
    |> check_rendered!(format)
  end

  # https://github.com/phoenixframework/phoenix_live_view/blob/27ae991d613ec163f45fc5bfc857e3a66c426af6/lib/phoenix_live_view/utils.ex#L243
  defp check_rendered!(%Phoenix.LiveView.Rendered{} = rendered, _format), do: rendered

  defp check_rendered!(other, format) do
    raise Beacon.LoaderError, """
    expected the stage :render of format #{format} to return a %Phoenix.LiveView.Rendered{} struct

    Got:

        #{inspect(other)}

    """
  end

  defp fetch_steps!(format, available_formats, stage) do
    case Enum.find(available_formats, fn {identifier, _, _} -> identifier == format end) do
      {_, _, steps} ->
        Keyword.fetch!(steps, stage)

      _ ->
        raise Beacon.LoaderError, """
        expected a template registered for the format #{format}, but none was found.

        Make sure that format is properly registered at `:template_formats` in the site config,
        see `Beacon.Config` for more info.

        """
    end
  end

  defp execute_steps(steps, stage, template, metadata) do
    Enum.reduce_while(steps, template, fn {step, fun}, acc ->
      case fun.(acc, metadata) do
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

              {:cont, template}
              {:halt, template}
              {:halt, exception}

          Got:

              #{inspect(other)}

          """
      end
    end)
  rescue
    e ->
      message = """
      expected stage #{stage} to define steps returning one of the following:

              {:cont, template}
              {:halt, template}
              {:halt, exception}

      Got:

          #{inspect(e)}

      """

      reraise Beacon.LoaderError, [message: message], __STACKTRACE__
  end

  @doc """
  Run all `:publish_page` steps defined in `t:Beacon.Config.t/0`.

  It's executed after the `page` is updated and a new page version is created but before it's reloaded.

  Give you the opportunity to transform the page or execude side actions before the page becomes public.
  """
  @spec publish_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def publish_page(page) do
    # TODO execute_steps
    page
  end
end
