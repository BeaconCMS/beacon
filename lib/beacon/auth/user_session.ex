defmodule Beacon.Auth.UserSession do
  @moduledoc """
  Represents an authenticated session for a Beacon user.

  Each session holds a unique random token used to identify the user
  across requests via a cookie.
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  @timestamps_opts updated_at: false

  schema "beacon_user_sessions" do
    field :token, :binary

    belongs_to :user, Beacon.Auth.User

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(session \\ %__MODULE__{}, attrs) do
    session
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> put_token()
  end

  defp put_token(changeset) do
    put_change(changeset, :token, :crypto.strong_rand_bytes(32))
  end
end
