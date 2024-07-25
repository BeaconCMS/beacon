defmodule Beacon.Web.FallbackController do
  @moduledoc false

  use Beacon.Web, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: Beacon.Web.ChangesetJSON)
    |> render("error.json", changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: Beacon.Web.ErrorHTML, json: Beacon.Web.ErrorJSON)
    |> render(:"404")
  end
end
