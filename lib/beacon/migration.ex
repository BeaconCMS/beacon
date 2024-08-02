defmodule Beacon.Migration do
  @moduledoc """
  Functions which can be called in an Ecto migration for Beacon installation and upgrades.

  ## Usage

  To install Beacon, you'll need to generate an `Ecto.Migration` that wraps calls to `Beacon.Migration`:

  ```
  $ mix ecto.gen.migration create_beacon_tables
  ```

  Open the generated migration in your editor and either call or delegate to `up/1` and `down/1`:

  ```elixir
  defmodule MyApp.Repo.Migrations.CreateBeaconTables do
    use Ecto.Migration
    def up, do: Beacon.Migration.up()
    def down, do: Beacon.Migration.down()
  end
  ```

  Then, run the migrations for your app to create the necessary Beacon tables in your database:

  ```
  $ mix ecto.migrate
  ```

  By calling `up()` with no arguments, this will execute all migration steps from the initial version to
  the latest version.  As new versions are released, you may need to repeat this process, by first
  generating a new migration:

  ```
  $ mix ecto.gen.migration upgrade_beacon_tables_to_v2
  ```

  Then in the generated migration, you could simply call `up()` again, because the migrations are
  idempotent, but you can be safer and more efficient by specifying the migration version to execute:

  ```elixir
   defmodule MyApp.Repo.Migrations.UpgradeBeaconTables do
    use Ecto.Migration
    def up, do: Beacon.Migration.up(version: 2)
    def down, do: Beacon.Migration.down(version: 2)
  end
  ```

  Now this migration will update to v2, but if rolled back, will only roll back the v2 changes,
  leaving v1 tables in-place.

  To see this step within the larger context of installing Beacon, check out the [your first site](your-first-site.html) guide.
  """

  @initial_version 1
  @current_version 2

  @doc """
  Upgrades Beacon database schemas.

  If a specific version number is provided, Beacon will only upgrade to that version.
  Otherwise, it will bring you fully up-to-date with the current version.

  ## Example

  Run all migrations up to the current version:

      Beacon.Migration.up()

  Run migrations up to a specified version:

      Beacon.Migration.down(version: 2)

  """
  def up(opts \\ []) do
    versions_to_run =
      case opts[:version] do
        nil -> @initial_version..@current_version//1
        version -> @initial_version..version//1
      end

    Enum.each(versions_to_run, fn version ->
      padded = String.pad_leading("#{version}", 3, "0")

      [Beacon.Migrations, "V#{padded}"]
      |> Module.concat()
      |> apply(:up, [])
    end)
  end

  @doc """
  Downgrades Beacon database schemas.

  If a specific version number is provided, Beacon will only downgrade to that version (inclusive).
  Otherwise, it will completely uninstall Beacon from your app's database.

  ## Example

  Run all migrations from current version down to the first:

      Beacon.Migration.down()

  Run migrations down to and including a specified version:

      Beacon.Migration.down(version: 2)

  """
  def down(opts \\ []) do
    versions_to_run =
      case opts[:version] do
        nil -> @current_version..@initial_version//-1
        version -> @current_version..version//-1
      end

    Enum.each(versions_to_run, fn version ->
      padded = String.pad_leading("#{version}", 3, "0")

      [Beacon.Migrations, "V#{padded}"]
      |> Module.concat()
      |> apply(:down, [])
    end)
  end
end
