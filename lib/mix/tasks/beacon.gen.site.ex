defmodule Mix.Tasks.Beacon.Gen.Site do
  use Igniter.Mix.Task

  @example "mix beacon.gen.site --site my_site --path /"
  @shortdoc "Generates a new Beacon site in the current project."

  @test? Beacon.Config.env_test?()

  @moduledoc """
  #{@shortdoc}

  Remember to execute [`mix beacon.install`](https://hexdocs.pm/beacon/Mix.Tasks.Beacon.Install.html)
  first if this is the first site you're generating in your project and you have not installed Beacon yet.

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--site` or `-s` (required) - The name of your site. Should not contain special characters nor start with "beacon_"
  * `--path` or `-p` (optional, defaults to "/") - Where your site will be mounted. Follows the same convention as Phoenix route prefixes.

  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :beacon,
      example: @example,
      schema: [site: :string, path: :string],
      aliases: [s: :site, p: :path],
      defaults: [path: "/"],
      required: [:site]
    }
  end

  @doc false
  def igniter(igniter) do
    options = igniter.args.options
    site = Keyword.fetch!(options, :site) |> String.to_atom()
    path = Keyword.fetch!(options, :path)
    validate_options!(site, path)

    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
    {igniter, [endpoint]} = Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)
    repo = Igniter.Project.Module.module_name(igniter, "Repo")

    igniter
    |> create_migration(repo)
    |> add_use_beacon_in_router(router)
    |> add_beacon_pipeline_in_router(router)
    |> mount_site_in_router(router, site, path)
    |> add_site_config_in_config_runtime(site, repo, router, endpoint)
    |> add_beacon_config_in_app_supervisor(site, repo, endpoint)
    |> Igniter.add_notice("""
    Site #{inspect(site)} generated successfully.

    The site is usually mounted in the same scope as the one used by the host application,
    in a best effort case to avoid conflicts, but conflicts can still happen or the site
    might not be mounted in the most appropriate order for your application.

    See the Route Precedence section in the Beacon.Router docs for more information.

    https://hexdocs.pm/beacon/Beacon.Router.html
    """)
  end

  defp validate_options!(site, path) do
    cond do
      !Beacon.Types.Site.valid?(site) -> raise_with_help!("Invalid site name. It should not contain special characters.", site, path)
      !Beacon.Types.Site.valid_name?(site) -> raise_with_help!("Invalid site name. The site name can't start with \"beacon_\".", site, path)
      !Beacon.Types.Site.valid_path?(path) -> raise_with_help!("Invalid path value. It should start with /.", site, path)
      :else -> :ok
    end
  end

  defp raise_with_help!(msg, site, path) do
    Mix.raise("""
    #{msg}

    mix beacon.install expects a valid site name, for example:

        mix beacon.install --site blog
        or
        mix beacon.install --site blog --path "/blog_path"

    Got:

      site: #{inspect(site)}
      path: #{inspect(path)}

    """)
  end

  defp add_use_beacon_in_router(igniter, router) do
    Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
      case Igniter.Code.Module.move_to_use(zipper, Beacon.Router) do
        {:ok, zipper} ->
          {:ok, zipper}

        _ ->
          with {:ok, zipper} <- Igniter.Libs.Phoenix.move_to_router_use(igniter, zipper) do
            {:ok, Igniter.Code.Common.add_code(zipper, "use Beacon.Router")}
          end
      end
    end)
  end

  defp add_beacon_pipeline_in_router(igniter, router) do
    Igniter.Libs.Phoenix.add_pipeline(
      igniter,
      :beacon,
      "plug Beacon.Plug",
      router: router
    )
  end

  defp create_migration(igniter, repo) do
    timestamp = if @test?, do: [timestamp: 0], else: []

    Igniter.Libs.Ecto.gen_migration(
      igniter,
      repo,
      "create_beacon_tables",
      [
        body: """
        def up, do: Beacon.Migration.up()
        def down, do: Beacon.Migration.down()
        """,
        on_exists: :skip
      ] ++ timestamp
    )
  end

  defp mount_site_in_router(igniter, router, site, path) do
    case Igniter.Project.Module.find_module(igniter, router) do
      {:ok, {_igniter, _source, zipper}} ->
        exists? =
          Sourceror.Zipper.find(
            zipper,
            &match?({:beacon_site, _, [{_, _, [^path]}, [{{_, _, [:site]}, {_, _, [^site]}}]]}, &1)
          )

        if exists? do
          Igniter.add_warning(
            igniter,
            "Site already exists: #{site}, skipping creation."
          )
        else
          Igniter.Libs.Phoenix.append_to_scope(
            igniter,
            "/",
            """
            beacon_site #{inspect(path)}, site: #{inspect(site)}
            """,
            with_pipelines: [:browser, :beacon],
            router: router,
            arg2: Igniter.Libs.Phoenix.web_module(igniter)
          )
        end

      _ ->
        :skip
    end
  end

  defp add_site_config_in_config_runtime(igniter, site, repo, router, endpoint) do
    Igniter.Project.Config.configure(
      igniter,
      "runtime.exs",
      :beacon,
      [site],
      {:code,
       Sourceror.parse_string!("""
       [site: :#{site}, repo: #{inspect(repo)}, endpoint: #{inspect(endpoint)}, router: #{inspect(router)}]
       """)}
    )
  end

  defp add_beacon_config_in_app_supervisor(igniter, site, repo, endpoint) do
    Igniter.Project.Application.add_new_child(
      igniter,
      {Beacon,
       {:code,
        quote do
          [sites: [Application.fetch_env!(:beacon, unquote(site))]]
        end}},
      after: [repo, endpoint],
      opts_updater: fn zipper ->
        with {:ok, zipper} <-
               Igniter.Code.Keyword.put_in_keyword(
                 zipper,
                 [:sites],
                 Sourceror.parse_string!("[Application.fetch_env!(:beacon, :#{site})]"),
                 fn zipper ->
                   exists? =
                     Sourceror.Zipper.find(
                       zipper,
                       &match?({{_, _, [{_, _, [:Application]}, :fetch_env!]}, _, [{_, _, [:beacon]}, {_, _, [^site]}]}, &1)
                     )

                   if exists? do
                     {:ok, zipper}
                   else
                     Igniter.Code.List.append_to_list(
                       zipper,
                       Sourceror.parse_string!("Application.fetch_env!(:beacon, :#{site})")
                     )
                   end
                 end
               ) do
          {:ok, zipper}
        else
          :error -> {:warning, ["Failed to automatically add your site."]}
        end
      end
    )
  end
end
