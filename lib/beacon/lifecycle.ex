defmodule Beacon.Lifecycle do
  @moduledoc """
  TODO
  """

  def load_template(page) do
    config = Beacon.Config.fetch!(page.site)
    metadata = %Beacon.Template.LoadMetadata{site: page.site, path: page.path}

    page.format
    |> fetch_steps!(config.template_formats, :load)
    |> execute_steps(page.template, metadata)
  end

  def render_template(site, path, format, template, assigns, env) do
    config = Beacon.Config.fetch!(site)
    metadata = %Beacon.Template.RenderMetadata{site: site, path: path, assigns: assigns, env: env}

    format
    |> fetch_steps!(config.template_formats, :render)
    |> execute_steps(template, metadata)
  end

  defp fetch_steps!(format, available_formats, stage) do
    dbg(format)
    dbg(available_formats)
    dbg(stage)

    case Enum.find(available_formats, fn {identifier, _, _} -> identifier == format end) do
      {_, _, steps} ->
        Keyword.fetch!(steps, stage)

      # TODO: handle instead of raise
      _ ->
        raise Beacon.LoaderError
    end
  end

  defp execute_steps(steps, template, metadata) do
    Enum.reduce_while(steps, template, fn {_step, fun}, acc ->
      fun.(acc, metadata)
    end)
  end
end
