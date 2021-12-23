defmodule Beacon.DataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data(site, path, params) do
    get_data_source().live_data(site, path, params)
  end

  def get_data_source do
    Application.fetch_env!(:beacon, :data_source)
  end
end
