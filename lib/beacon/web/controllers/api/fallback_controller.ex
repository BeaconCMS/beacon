defmodule Beacon.Web.API.FallbackController do
  @moduledoc false

  use Beacon.Web, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: Beacon.Web.API.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
