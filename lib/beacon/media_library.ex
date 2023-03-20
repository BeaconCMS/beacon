defmodule Beacon.MediaLibrary do
  @moduledoc """
  """

  import Ecto.Query, warn: false
  alias Beacon.Repo

  alias Beacon.MediaLibrary.Asset

  def get_asset(site, name) do
    Repo.get_by(Asset, site: site, file_name: name)
  end
end
