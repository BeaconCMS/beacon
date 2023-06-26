defmodule Beacon.MediaLibrary do
  # TODO: docs
  @moduledoc """
  MediaLibrary
  """
  import Ecto.Query, warn: false

  alias Beacon.MediaLibrary.Asset
  alias Beacon.Repo

  def get_asset(site, name) do
    Repo.one(
      from(a in Asset,
        where: a.site == ^site,
        where: a.file_name == ^name,
        where: is_nil(a.deleted_at)
      )
    )
  end
end
