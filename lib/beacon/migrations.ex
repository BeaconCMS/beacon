defmodule Beacon.Migrations do
  @current_version 4
  @moduledoc """

  This module generates migrations in your app for the Beacon tables.

  Your application should include a migration file generated with the following command:

    mix ecto.gen.migration beacon_migration_to_#{@current_version}

  Remove the generated change/1 function and instead add:

  use Beacon.Migrations, from: 1, to: #{@current_version}.

  If you have already run migrations for an earlier version than #{@current_version}, you should generate
  another migration file using the same above command, but with "from" one higher than your previous "to".

  For example, if you already have a migration with:

    use Beacon.Migrations, from: 1, to: 2

  You should generate a new migration file with:

    use Beacon.Migrations, from: 3, to: #{@current_version}.

  Do *not* modify migrations that have already been run.
  """

  defmacro __using__(opts) do
    from = Keyword.get(opts, :from)
    to = Keyword.get(opts, :to)

    if !is_integer(from) or from < 1 do
      raise "`use Beacon.Migrations, from: x, to: x` requires a positive integer `from:` value"
    end

    if !is_integer(to) or to < 1 do
      raise "`use Beacon.Migrations, from: x, to: x` requires a positive integer `to:` value"
    end

    migrations =
      for i <- from..to do
        migration(i)
      end

    quote do
      def change do
        unquote(migrations)
      end
    end
  end

  def migration(1) do
    quote do
      create table(:layouts, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:site, :text)
        add(:title, :text)
        add(:body, :text)
        add(:meta_tags, :map)
        add(:stylesheets, {:array, :text})

        timestamps()
      end
    end
  end

  def migration(2) do
    quote do
      create table(:pages, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:path, :text)
        add(:site, :text)
        add(:template, :text)
        add(:pending_template, :text)
        add(:version, :integer, default: 1)

        add(:layout_id, references(:layouts, type: :binary_id))
        add(:pending_layout_id, references(:layouts, type: :binary_id))

        timestamps()
      end

      create(unique_index(:pages, [:path, :site]))
    end
  end

  def migration(3) do
    quote do
      create table(:components, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:site, :text)
        add(:name, :text)
        add(:body, :text)

        timestamps()
      end
    end
  end

  def migration(4) do
    quote do
      create table(:page_versions, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:version, :integer)
        add(:template, :text)
        add(:page_id, references(:pages, on_delete: :nothing, type: :binary_id))

        timestamps()
      end

      create(index(:page_versions, [:page_id]))
    end
  end
end
