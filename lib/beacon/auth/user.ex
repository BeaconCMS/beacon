defmodule Beacon.Auth.User do
  @moduledoc """
  Represents a Beacon CMS user.

  Users authenticate via OIDC providers or local password (dev mode).
  Authorization is managed through `Beacon.Auth.UserRole`.
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_users" do
    field :email, :string
    field :name, :string
    field :hashed_password, :string
    field :avatar_url, :string
    field :last_login_at, :utc_datetime_usec
    field :last_login_provider, :string
    field :password, :string, virtual: true

    has_many :roles, Beacon.Auth.UserRole
    has_many :sessions, Beacon.Auth.UserSession

    timestamps()
  end

  @doc false
  def changeset(user \\ %__MODULE__{}, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url, :last_login_at, :last_login_provider])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    |> unique_constraint(:email)
  end

  @doc false
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> hash_password()
  end

  defp hash_password(%Changeset{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  defp hash_password(changeset), do: changeset
end
