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
      example: @example,
      composes: ["beacon.gen.site"],
      schema: [site: :string, path: :string],
      aliases: [s: :site, p: :path],
      defaults: [path: "/"]
    }
  end

  @doc false
  def igniter(igniter, argv \\ []) do
    {_arguments, argv} = positional_args!(argv)
    _options = options!(argv)

    igniter
    |> Igniter.Project.Formatter.import_dep(:beacon)
    |> error_html()

    # |> gen_site(options, argv)
  end

  defp error_html(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
    {igniter, [endpoint]} = Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [endpoint, :render_errors, :formats, :html],
      {:code, Sourceror.parse_string!("Beacon.Web.ErrorHTML")}
    )
  end

  # defp gen_site(igniter, options, argv) do
  #   if options[:site] do
  #     Igniter.compose_task("beacon.gen.site", argv)
  #   else
  #     igniter
  #   end
  # end
end
