defmodule Beacon.Web.ChangesetJSON do
  @moduledoc false

  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &Beacon.Web.CoreComponents.translate_error/1)
  end

  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: translate_errors(changeset)}
  end
end
