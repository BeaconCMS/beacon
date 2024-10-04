defmodule Mix.Tasks.Beacon.Gen.Site do
  use Igniter.Mix.Task

  @example "mix beacon.gen.site --example arg"

  @shortdoc "A short description of your task"
  @moduledoc """
  #{@shortdoc}

  Longer explanation of your task

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--example-option` or `-e` - Docs for your option
  """

  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      # dependencies to add
      adds_deps: [],
      # dependencies to add and call their associated installers, if they exist
      installs: [],
      # An example invocation
      example: @example,
      # Accept additional arguments that are not in your schema
      # Does not guarantee that, when composed, the only options you get are the ones you define
      extra_args?: false,
      # A list of environments that this should be installed in, only relevant if this is an installer.
      only: nil,
      # a list of positional arguments, i.e `[:file]`
      positional: [],
      # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
      # This ensures your option schema includes options from nested tasks
      composes: [],
      # `OptionParser` schema
      schema: [path: :string, site: :string],
      # CLI aliases
      aliases: [p: :path, s: :site]
    }
  end

  def igniter(igniter, argv) do
    # extract positional arguments according to `positional` above
    {arguments, argv} = positional_args!(argv)
    # extract options according to `schema` and `aliases` above
    options = options!(argv)

    options =
      options
      |> Keyword.put_new(:path, "/")
      |> Keyword.put_new(:site, "my_site")

    path = Keyword.get(options, :path)
    site = Keyword.get(options, :site) |> String.to_atom()

    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
    {igniter, [endpoint]} = Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)
    repo = Igniter.Project.Module.module_name(igniter, "Repo")

    # Do your work here and return an updated igniter
    igniter
    # FIXME: priv path
    # |> Igniter.Project.Module.create_module(migration_name, "", location: {:source_folder, "priv"})
    # |> Igniter.add_task("ecto.gen.migration", ["create_beacon_tables"])
    # |> Igniter.add_notice("modify your migration file to call Beacon migration")
    |> create_migration()
    |> Igniter.Libs.Phoenix.append_to_scope(
      "/",
      """
      beacon_site #{inspect(path)}, site: #{inspect(site)}
      """,
      with_pipelines: [:browser],
      router: router
    )
    |> add_beacon_in_router(router)
    |> Igniter.Project.Application.add_new_child(
      {Beacon,
       sites: [
         [
           site: site,
           repo: repo,
           endpoint: endpoint,
           router: router
         ]
       ]},
      after: [repo, endpoint]
    )
  end

  defp add_beacon_in_router(igniter, router) do
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

  defp migration_module_name(igniter) do
    Igniter.Project.Module.module_name(igniter, "Repo.Migrations.CreateBeaconTables")
  end

  defp create_migration(igniter) do
    {exists, igniter} = Igniter.Project.Module.module_exists?(igniter, migration_module_name(igniter))

    if exists do
      igniter
      |> Igniter.create_new_elixir_file("priv/repo/migrations/#{migration_timestamp()}_create_beacon_tables.exs", """
      defmodule #{inspect(migration_module_name(igniter))} do
        use Ecto.Migration
        def up, do: Beacon.Migration.up()
        def down, do: Beacon.Migration.down()
      end
      """)
      |> Igniter.add_notice("run mix ecto.migrate")
    else
      igniter
    end
  end

  defp migration_timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
