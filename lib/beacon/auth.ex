defmodule Beacon.Auth do
  @moduledoc """
  Authentication and authorization context for Beacon CMS.

  Provides user management, session handling, role-based authorization,
  and OIDC integration. For platform-level operations (users, roles,
  sessions), uses the repo from the first running Beacon site.
  """

  import Ecto.Query

  alias Beacon.Auth.User
  alias Beacon.Auth.UserRole
  alias Beacon.Auth.UserSession

  # ---------------------------------------------------------------------------
  # Repo Helper
  # ---------------------------------------------------------------------------

  defp repo do
    site = Beacon.Registry.running_sites() |> List.first()
    Beacon.Config.fetch!(site).repo
  end

  # ---------------------------------------------------------------------------
  # User CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new user.

  ## Examples

      iex> Beacon.Auth.create_user(%{email: "user@example.com", name: "User"})
      {:ok, %Beacon.Auth.User{}}

  """
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates an existing user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a user and all associated sessions and roles (via cascading delete).
  """
  def delete_user(%User{} = user) do
    repo().delete(user)
  end

  @doc """
  Lists users with optional pagination.

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Results per page (default: 20)

  """
  def list_users(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    User
    |> order_by([u], asc: u.email)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> repo().all()
  end

  @doc """
  Gets a user by ID. Returns `nil` if not found.
  """
  def get_user(id) do
    repo().get(User, id)
  end

  @doc """
  Gets a user by email. Returns `nil` if not found.
  """
  def get_user_by_email(email) when is_binary(email) do
    repo().get_by(User, email: email)
  end

  # ---------------------------------------------------------------------------
  # Password (dev mode)
  # ---------------------------------------------------------------------------

  @doc """
  Sets a password for the given user by hashing it with Bcrypt.
  """
  def set_password(%User{} = user, password) when is_binary(password) do
    user
    |> User.password_changeset(%{password: password})
    |> repo().update()
  end

  @doc """
  Verifies a plaintext password against the user's stored hash.

  Returns `true` if the password matches, `false` otherwise.
  Always performs a dummy check when no hash is stored to prevent timing attacks.
  """
  def verify_password(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and is_binary(password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def verify_password(_user, _password) do
    Bcrypt.no_user_verify()
    false
  end

  # ---------------------------------------------------------------------------
  # Sessions
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new session for the given user.

  Returns the raw token binary that should be stored in the client cookie.
  """
  def create_session(%User{} = user) do
    changeset = UserSession.changeset(%UserSession{}, %{user_id: user.id})

    case repo().insert(changeset) do
      {:ok, session} -> {:ok, session.token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Looks up a user by their session token.

  Returns the user struct or `nil` if the session is invalid.
  """
  def get_user_by_session_token(token) when is_binary(token) do
    session =
      UserSession
      |> where([s], s.token == ^token)
      |> join(:inner, [s], u in assoc(s, :user))
      |> select([s, u], u)
      |> repo().one()

    session
  end

  def get_user_by_session_token(_), do: nil

  @doc """
  Deletes a session by token.
  """
  def delete_session(token) when is_binary(token) do
    UserSession
    |> where([s], s.token == ^token)
    |> repo().delete_all()

    :ok
  end

  @doc """
  Deletes all sessions for the given user.
  """
  def delete_user_sessions(%User{} = user) do
    UserSession
    |> where([s], s.user_id == ^user.id)
    |> repo().delete_all()

    :ok
  end

  # ---------------------------------------------------------------------------
  # Roles
  # ---------------------------------------------------------------------------

  @doc """
  Assigns a role to a user, optionally scoped to a site.
  """
  def assign_role(%User{} = user, role, site \\ nil) do
    %UserRole{}
    |> UserRole.changeset(%{user_id: user.id, role: to_string(role), site: site})
    |> repo().insert()
  end

  @doc """
  Revokes a role from a user, optionally scoped to a site.
  """
  def revoke_role(%User{} = user, role, site \\ nil) do
    query =
      UserRole
      |> where([r], r.user_id == ^user.id and r.role == ^to_string(role))

    query =
      if is_nil(site) do
        where(query, [r], is_nil(r.site))
      else
        where(query, [r], r.site == ^site)
      end

    repo().delete_all(query)
    :ok
  end

  @doc """
  Lists all roles for the given user.
  """
  def list_roles(%User{} = user) do
    UserRole
    |> where([r], r.user_id == ^user.id)
    |> repo().all()
  end

  @doc """
  Returns `true` if the user has the specified role (optionally scoped to a site).
  """
  def has_role?(%User{} = user, role, site \\ nil) do
    query =
      UserRole
      |> where([r], r.user_id == ^user.id and r.role == ^to_string(role))

    query =
      if is_nil(site) do
        where(query, [r], is_nil(r.site))
      else
        where(query, [r], r.site == ^site)
      end

    repo().exists?(query)
  end

  @doc """
  Returns `true` if the user is a super admin.
  """
  def is_super_admin?(%User{} = user) do
    has_role?(user, "super_admin")
  end

  @doc """
  Returns `true` if the user can access the given site.

  A user can access a site if they are a super_admin or hold any role for that site.
  """
  def can_access_site?(%User{} = user, site) do
    is_super_admin?(user) ||
      UserRole
      |> where([r], r.user_id == ^user.id and r.site == ^site)
      |> repo().exists?()
  end

  @doc """
  Checks authorization and raises `Beacon.Auth.UnauthorizedError` if the user
  is not permitted to perform the given action on the site.

  Actions map to minimum required roles:

    * `:manage` - requires `super_admin` or `site_admin`
    * `:edit` - requires `super_admin`, `site_admin`, or `site_editor`
    * `:view` - requires any role for the site or `super_admin`

  """
  def authorize!(%User{} = user, action, site) do
    authorized =
      case action do
        :manage ->
          is_super_admin?(user) || has_role?(user, "site_admin", site)

        :edit ->
          is_super_admin?(user) ||
            has_role?(user, "site_admin", site) ||
            has_role?(user, "site_editor", site)

        :view ->
          can_access_site?(user, site)

        _ ->
          false
      end

    unless authorized do
      raise Beacon.Auth.UnauthorizedError,
        message: "user #{user.email} is not authorized to #{action} on site #{inspect(site)}"
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # OIDC
  # ---------------------------------------------------------------------------

  @doc """
  Authenticates a user via OIDC by email lookup.

  Updates the last login timestamp and provider. Returns `{:error, :not_found}`
  if no user with the given email exists.
  """
  def authenticate_oidc(email, provider \\ "oidc") when is_binary(email) do
    case get_user_by_email(email) do
      nil ->
        {:error, :not_found}

      user ->
        user
        |> User.changeset(%{last_login_at: DateTime.utc_now(), last_login_provider: provider})
        |> repo().update()
    end
  end
end
