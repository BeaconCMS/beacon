defmodule Beacon.Repo.Migrations.MigratePageSnapshots do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_page_variant_snapshots, primary_key: false) do
      add :id, :binary_id
      add :name, :text
      add :template, :text
      add :weight, :integer
      add :page_id, :binary_id
      add :event_id, references(:beacon_page_events, on_delete: :delete_all, type: :binary_id)
      timestamps()
    end

    create_if_not_exists table(:beacon_page_event_handler_snapshots, primary_key: false) do
      add :id, :binary_id
      add :name, :text
      add :code, :text
      add :page_id, :binary_id
      add :event_id, references(:beacon_page_events, on_delete: :delete_all, type: :binary_id)
      timestamps()
    end

    drop_if_exists constraint("beacon_page_snapshots", "beacon_page_snapshots_pkey")

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :path, :text
      add_if_not_exists :title, :text
      add_if_not_exists :description, :text
      add_if_not_exists :template, :text
      add_if_not_exists :meta_tags, :map
      add_if_not_exists :raw_schema, {:array, :map}
      add_if_not_exists :format, :text
      add_if_not_exists :extra, :map
      add_if_not_exists :helpers, :map
      add_if_not_exists :layout_id, :binary_id
      add_if_not_exists :updated_at, :naive_datetime
    end

    for %{id: id, event_id: event_id, page: page} <- snapshots() do
      update_snapshot(id, page)
      insert_variant_snapshots(page.variants, event_id)
      insert_event_handler_snapshots(page.event_handlers, event_id)
    end

    alter table(:beacon_page_snapshots) do
      remove :schema_version
      remove :page_id
      remove :page
    end
  end

  defp snapshots do
    query = """
    SELECT id, schema_version, event_id, page_id, page FROM beacon_page_snapshots
    """

    schema = %{
      id: :binary_id,
      schema_version: :integer,
      event_id: :binary_id,
      page_id: :binary_id,
      page: Beacon.Types.Binary
    }

    case repo().query(query, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          snapshot = repo().load(schema, {result.columns, row})
          page = extract_page_snapshot(snapshot)
          helpers = Enum.map(page.helpers, &Map.from_struct/1)
          page = %{page | helpers: helpers}
          %{snapshot | page: page}
        end)

      _ ->
        []
    end
  end

  defp update_snapshot(id, page) do
    id = Ecto.UUID.dump!(id)
    page_id = Ecto.UUID.dump!(page.id)
    layout_id = Ecto.UUID.dump!(page.layout_id)
    site = Atom.to_string(page.site)
    format = Atom.to_string(page.format)

    execute(fn ->
      repo().query!(
        """
        UPDATE beacon_page_snapshots
           SET id = $15,
               site = $2,
               path = $3,
               title = $4,
               description = $5,
               template = $6,
               meta_tags = $7,
               raw_schema = $8,
               format = $9,
               extra = $10,
               helpers = $11,
               layout_id = $12,
               inserted_at = $13,
               updated_at = $14
         WHERE id = $1
        """,
        [
          id,
          site,
          page.path,
          page.title,
          page.description,
          page.template,
          page.meta_tags,
          page.raw_schema,
          format,
          page.extra,
          page.helpers,
          layout_id,
          page.inserted_at,
          page.updated_at,
          page_id
        ],
        log: :info
      )
    end)
  end

  defp insert_variant_snapshots(variants, event_id) do
    variants =
      Enum.map(variants, fn variant ->
        variant =
          variant
          |> Map.from_struct()
          |> Map.take([:id, :name, :template, :weight, :page_id, :inserted_at, :updated_at])
          |> Map.put(:event_id, Ecto.UUID.dump!(event_id))

        %{variant | id: Ecto.UUID.dump!(variant.id), page_id: Ecto.UUID.dump!(variant.page_id)}
      end)

    repo().insert_all("beacon_page_variant_snapshots", variants)
  end

  defp insert_event_handler_snapshots(event_handlers, event_id) do
    event_handlers =
      Enum.map(event_handlers, fn event_handler ->
        event_handler =
          event_handler
          |> Map.from_struct()
          |> Map.take([:id, :name, :code, :page_id, :inserted_at, :updated_at])
          |> Map.put(:event_id, Ecto.UUID.dump!(event_id))

        %{
          event_handler
          | id: Ecto.UUID.dump!(event_handler.id),
            page_id: Ecto.UUID.dump!(event_handler.page_id)
        }
      end)

    repo().insert_all("beacon_page_event_handler_snapshots", event_handlers)
  end

  defp extract_page_snapshot(%{schema_version: 1, page: page}) do
    page
    |> repo().reload()
    |> repo().preload([:variants, :event_handlers], force: true)
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(%{schema_version: 2, page: page}) do
    page
    |> repo().reload()
    |> repo().preload([:variants, :event_handlers], force: true)
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(%{schema_version: 3, page: page}) do
    page
    |> maybe_add_leading_slash()
  end

  defp extract_page_snapshot(_snapshot), do: nil

  defp maybe_add_leading_slash(%{path: <<"/", _rest::binary>>} = page), do: page

  defp maybe_add_leading_slash(page) do
    path = "/" <> page.path
    %{page | path: path}
  end

  def down do
  end
end
