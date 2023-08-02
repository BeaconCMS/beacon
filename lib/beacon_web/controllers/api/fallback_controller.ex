defmodule BeaconWeb.API.FallbackController do
  @moduledoc false

  use BeaconWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: BeaconWeb.API.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
