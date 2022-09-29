defmodule Beacon.Loader.Server do
  use GenServer

  alias Beacon.Loader.DBLoader

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def reload_from_db do
    GenServer.call(__MODULE__, :reload_from_db)
  end

  def init(_opts) do
    Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :up, all: true))
    load_from_db()
    {:ok, %{}}
  end

  def handle_call(:reload_from_db, _from, state) do
    load_from_db()
    {:reply, :ok, state}
  end

  defp load_from_db do
    DBLoader.load_from_db()
  end
end
