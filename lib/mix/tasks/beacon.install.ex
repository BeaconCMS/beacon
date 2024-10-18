defmodule Mix.Tasks.Beacon.Install do
  use Igniter.Mix.Task

  @example "mix beacon.install --site my_site --path /"

  @shortdoc "Install Beacon in a Phoenix LiveView app"
  @moduledoc """
  #{@shortdoc}

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--site` or `-s` (required) - The name of your site
  * `--path` or `-p` (optional, defaults to "/") - Route prefix where your site will be mounted

  """

  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      example: @example,
      composes: ["beacon.gen.site"],
      schema: [path: :string, site: :string],
      aliases: [p: :path, s: :site],
      defaults: [path: "/"]
    }
  end

  def igniter(igniter, argv) do
    {_arguments, argv} = positional_args!(argv)
    options = options!(argv)

    dbg options

    igniter
    |> Igniter.Project.Formatter.import_dep(:beacon)
    |> gen_site(options, argv)
  end

  defp gen_site(igniter, options, argv) do
    if options[:site] do
      Igniter.compose_task("beacon.gen.site", argv)
    else
      igniter
    end
  end
end
