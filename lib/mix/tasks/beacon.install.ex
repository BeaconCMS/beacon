defmodule Mix.Tasks.Beacon.Install do
  use Igniter.Mix.Task

  @example "mix beacon.install --site my_site --path /"
  @shortdoc "Installs Beacon in a Phoenix LiveView app."

  @moduledoc """
  #{@shortdoc}

  It will add the necessary dependencies and configuration into your Phoenix LiveView app.

  The options `--site` and `--path` are optional but you can bootstrap a new site by providing them,
  otherwise execute [`mix beacon.gen.site`](https://hexdocs.pm/beacon/Mix.Tasks.Beacon.Gen.Site.html) at anytime to generate new sites.

  You might want to install [Beacon LiveAdmin](https://hexdocs.pm/beacon_live_admin/Mix.Tasks.Beacon.LiveAdmin.Install.html)
  as well to manage the content of your sites.

  ## Examples

  ```bash
  mix beacon.install
  ```

  ```bash
  #{@example}
  ```

  ## Options

  * `--site` or `-s` (optional) - The name of your site. Should not contain special characters nor start with "beacon_"
  * `--path` or `-p` (optional, defaults to "/") - Where your site will be mounted. Follows the same convention as Phoenix route prefixes.

  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :beacon,
      example: @example,
      composes: ["beacon.gen.site"],
      schema: [site: :string, path: :string],
      aliases: [s: :site, p: :path],
      defaults: [path: "/"]
    }
  end

  @doc false
  def igniter(igniter) do
    argv = igniter.args.argv
    options = igniter.args.options

    {igniter, router} = Beacon.Igniter.select_router!(igniter)

    igniter
    |> add_beacon_plugin_formatter()
    |> replace_error_html(router)
    |> maybe_gen_site(options, argv)
  end

  defp add_beacon_plugin_formatter(igniter) do
    Igniter.Project.Formatter.import_dep(igniter, :beacon)
  end

  defp replace_error_html(igniter, router) do
    app_name = Igniter.Project.Application.app_name(igniter)

    {igniter, endpoint} = Beacon.Igniter.select_endpoint!(igniter, router)

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [endpoint, :render_errors, :formats, :html],
      {:code, Sourceror.parse_string!("Beacon.Web.ErrorHTML")}
    )
  end

  defp maybe_gen_site(igniter, options, argv) do
    if options[:site] do
      Igniter.compose_task(igniter, "beacon.gen.site", argv)
    else
      igniter
    end
  end
end
