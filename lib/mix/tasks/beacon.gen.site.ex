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
  def igniter(igniter, argv) do
    {_arguments, argv} = positional_args!(argv)
    options = options!(argv)
    site = Keyword.fetch!(options, :site) |> String.to_atom()
    path = Keyword.fetch!(options, :path)
    validate_options!(site, path)

    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
    {igniter, [endpoint]} = Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)
    repo = Igniter.Project.Module.module_name(igniter, "Repo")

    igniter
    |> create_migration(repo)
    |> add_use_beacon_in_router(router)
    |> mount_site_in_router(router, site, path)
    |> add_beacon_config_in_app_supervisor(site, repo, router, endpoint)
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
        on_exists: :overwrite
      ] ++ timestamp
    )
  end

  defp mount_site_in_router(igniter, router, site, path) do
    Igniter.Libs.Phoenix.append_to_scope(
      igniter,
      "/",
      """
      beacon_site #{inspect(path)}, site: #{inspect(site)}
      """,
      with_pipelines: [:browser],
      router: router
    )
  end

  defp add_beacon_config_in_app_supervisor(igniter, site, repo, router, endpoint) do
    Igniter.Project.Application.add_new_child(
      igniter,
      {Beacon,
       sites: [
         [
           site: site,
           repo: repo,
           endpoint: endpoint,
           router: router
         ]
       ]},
      after: [repo, endpoint],
      opts_updater: fn zipper ->
        Igniter.Util.Debug.puts_code_at_node(zipper)

        with {:ok, zipper} <-
               Igniter.Code.Keyword.put_in_keyword(
                 zipper,
                 [:sites],
                 [
                   site: site,
                   repo: repo,
                   endpoint: endpoint,
                   router: router
                 ],
                 fn zipper ->
                   Igniter.Util.Debug.puts_code_at_node(zipper)

                   site_config = [
                     site: site,
                     repo: repo,
                     endpoint: endpoint,
                     router: router
                   ]

                   config = Sourceror.to_string(site_config) |> Sourceror.parse_string!()

                   Igniter.Code.List.append_to_list(
                     zipper,
                     config
                   )
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
