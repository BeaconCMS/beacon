defmodule Mix.Tasks.Beacon.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs Beacon in a Phoenix LiveView app."
  end

  def example do
    "mix beacon.install"
  end

  def long_doc do
    """
    #{short_doc()}

    It will add the necessary dependencies and configuration into your Phoenix LiveView app.

    The options `--site` and `--path` are optional but you can bootstrap a new site by providing them,
    otherwise execute [`mix beacon.gen.site`](https://hexdocs.pm/beacon/Mix.Tasks.Beacon.Gen.Site.html) at anytime to generate new sites.

    You might want to install [Beacon LiveAdmin](https://hexdocs.pm/beacon_live_admin/Mix.Tasks.Beacon.LiveAdmin.Install.html)
    as well to manage the content of your sites.

    ## Examples

    ```bash
    #{example()}
    ```

    ```bash
    mix beacon.install --site my_site --path /
    ```

    ## Options

    * `--site` (optional) - The name of your site. Should not contain special characters nor start with `"beacon_"`.
    * `--path` (optional, defaults to `"/"`) - Where your site will be mounted. Follows the same convention as Phoenix route prefixes.

    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Beacon.Install do
    use Igniter.Mix.Task

    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    @impl Igniter.Mix.Task
    def supports_umbrella?, do: true

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :beacon,
        example: __MODULE__.Docs.example(),
        composes: ["beacon.gen.site"],
        schema: [site: :string, path: :string],
        defaults: [path: "/"]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      if Mix.Project.umbrella?() do
        Mix.shell().error("""
        Running 'mix beacon.install' in the root of Umbrella apps is not supported yet.

        Please execute that task inside a child app.
        """)

        exit({:shutdown, 1})
      end

      argv = igniter.args.argv
      options = igniter.args.options

      {igniter, router} = Beacon.Igniter.select_router!(igniter)

      igniter
      |> add_beacon_plugin_formatter()
      |> replace_error_html(router)
      |> maybe_gen_site(options, argv)
      # TODO: remove this notice after Igniter supports Umbrella config files properly
      |> Igniter.add_warning("""
      Notice for Umbrella apps.
      Ignore if not running 'beacon.install' in an Umbrella child app.

      In this version we can't yet find the config files correctly,
      so it creates new files at ./config in the child app dir,
      which may not be correct as usually config files in Umbrella apps
      are located in the root of the project.
      If that's the case, please insert the suggested changes into the config files
      at the root of your project and remove the created config/ file from the child app.
      """)
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
else
  defmodule Mix.Tasks.Beacon.Install do
    @shortdoc "Install `igniter` in order to run Beacon generators."

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'beacon.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
