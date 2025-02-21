defmodule Beacon.Auth do
  @moduledoc """
  Role-based access control.

  Beacon's auth model uses actors, roles, and capabilities:

  ```
  [ACTOR] ---has-one--- [ROLE] ---has-many--- [CAPABILITIES]
  ```

  For example:

  ```
  user_1337 --- author --- create_page
                        |- update_page
                        |- publish_page
                        |- etc...
  ```

  To add auth to your Beacon application, there are two callbacks to implement:

    * `actor_from_session/1` - a function which receives the user's session data, and returns a tuple
      containing a unique ID and a human-readable label
    * `list_actors/0` - a function to return a list of actors, in the same format as above: `{id, label}`

  This allows you to integrate Beacon with any type of authentication system your app might require.

  ## Implementing the Beacon.Auth behaviour

  Let's take a look at the case where [`mix phx.gen.auth`](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html)
  was used to register and sign in users.

  ```
  defmodule MyApp.Auth do
    @behaviour Beacon.Auth

    def actor_from_session(session) do
      user = MyApp.Accounts.get_user_by_session_token(session["user_token"])

      {user.id, user.email}
    end

    def list_actors do
      Repo.all(from u in MyApp.Accounts.User, select: {u.id, u.email})
    end
  end
  ```

  In the above example, the `actor_from_session/1` function retrieves the `user_token` which is put
  into the session when a user logs in.  With that token, it fetches the `%User{}` struct from the database
  and returns the ID with the user's email as the label.

  `list_actors/0` provides the database query for Beacon to find the actors in your app and return
  them in the expected `{id, label}` format.

  This module can then be provided to `Beacon.Config` as an `:auth_module` option:

  ```
  config :beacon, :my_site,
    ...
    auth_module: MyApp.Auth,
    ...
  ```

  And now calls to Beacon can be authorized by passing the `:actor` option.  Continue to the next
  section for more details.

  ## Authorization Options

  Several functions in this module (and others) require authorization by default. This is done via the `:actor` option:

  ```
  iex> Beacon.Auth.create_role(%{"name" => "Power User", ...}, actor: "some-identifying-id")
  {:ok, %Role{}}
  ```

  Beacon will use your site's `t:Beacon.Config.auth_module/0` to determine the role for the given actor,
  and prevent the function from running if the role should not have access:

  ```
  iex> Beacon.Auth.create_role(%{"name" => "Power User", ...},, actor: "user-with-read-only-access")
  {:error, :not_authorized}
  ```

  To disable authorization for internal calls, pass the `auth: false` option:

  ```
  iex> Beacon.Auth.create_role(%{"name" => "Power User", ...}, auth: false)
  {:ok, %Role{}}
  ```
  """
  import Beacon.Utils, only: [repo: 1]
  import Ecto.Query

  alias Beacon.Auth.ActorRole
  alias Beacon.Auth.Role
  alias Beacon.Config
  alias Ecto.Changeset

  @type actor_tuple :: {id :: String.t(), label :: String.t()}

  @doc """
  Parses the actor's identity from the session.
  """
  @callback actor_from_session(session :: map()) :: actor_tuple() | nil

  @doc """
  Lists all actors for your beacon site, each in the form of a tuple containing a unique ID as well
  as a human-readable label.
  """
  @callback list_actors() :: [actor_tuple()]

  @doc """
  Specifies the identity of the site owner who should always have unconditional access.
  """
  @callback owner() :: actor_tuple()

  @doc """
  Check if an action is allowed.
  """
  @spec authorize(Site.t(), atom(), keyword()) :: :ok | {:error, :not_authorized}
  def authorize(site, action, opts) do
    {owner_id, _label} = get_owner(site)

    owner? =
      case opts[:actor] do
        {^owner_id, _label} -> true
        _otherwise -> false
      end

    if not owner? and Keyword.get(opts, :auth, true) do
      do_authorize(site, opts[:actor], action)
    else
      :ok
    end
  end

  defp do_authorize(site, actor, action) do
    with %{} = role <- get_role(site, actor),
         true <- to_string(action) in role.capabilities do
      :ok
    else
      _ -> {:error, :not_authorized}
    end
  end

  @doc """
  Uses a site's `:auth_module` from `Beacon.Config` to list all actors for a site.
  """
  @spec list_actors(Site.t()) :: [actor_tuple()]
  def list_actors(site) do
    Config.fetch!(site).auth_module.list_actors()
  end

  @doc """
  Uses a site's `:auth_module` from `Beacon.Config` to find the actor for a given session.
  """
  @spec get_actor(Site.t(), map()) :: actor_tuple()
  def get_actor(site, session) do
    Config.fetch!(site).auth_module.actor_from_session(session)
  end

  @doc """
  Uses a site's `:auth_module` from `Beacon.Config` to find the owner.
  """
  @spec get_owner(Site.t()) :: actor_tuple()
  def get_owner(site) do
    Config.fetch!(site).auth_module.owner()
  end

  defp get_role(site, {actor_id, _label}) do
    repo(site).one(
      from ar in ActorRole,
        join: r in Role,
        on: ar.role_id == r.id,
        where: ar.site == ^site,
        where: ar.actor_id == ^actor_id,
        select: r
    )
  end

  @doc """
  Returns all ActorRoles for a list of Actor IDs.

  This can be helpful for fetching Role IDs in bulk with only one query.

  Accepts option `preload: :role` to include the full Role schema instead of just the ID.
  """
  @spec get_actor_roles(Site.t(), [String.t()]) :: [ActorRole.t()]
  def get_actor_roles(site, ids, opts \\ []) do
    preload = opts[:preload] || []

    repo(site).all(
      from ar in ActorRole,
        where: ar.actor_id in ^ids,
        preload: ^preload
    )
  end

  @doc """
  Creates a changeset with the given role and optional map of changes.
  """
  @spec change_role(Role.t(), map()) :: Changeset.t()
  def change_role(role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end

  @doc """
  Lists all roles available for a given site.
  """
  @spec list_roles(Site.t()) :: [Role.t()]
  def list_roles(site) do
    repo(site).all(from r in Role, where: r.site == ^to_string(site))
  end

  @doc """

  """
  @spec default_role_capabilities() :: [atom()]
  def default_role_capabilities do
    []
  end

  @doc """
  Create a new role.
  """
  @spec create_role(map(), keyword()) :: {:ok, Role.t()} | {:error, Changeset.t()}
  def create_role(attrs, opts \\ []) do
    changeset = Role.changeset(%Role{}, attrs)
    site = Changeset.get_field(changeset, :site)

    with :ok <- authorize(site, :create_role, opts) do
      repo(site).insert(changeset)
    end
  end

  @doc """
  Update an existing role.
  """
  @spec update_role(Role.t(), map(), keyword()) :: {:ok, Role.t()} | {:error, Changeset.t()}
  def update_role(role, attrs, opts \\ []) do
    with :ok <- authorize(role.site, :update_role, opts) do
      role
      |> Role.changeset(attrs)
      |> repo(role).update()
    end
  end

  @doc """
  Delete an existing role.
  """
  @spec delete_role(Role.t(), keyword()) :: {:ok, Role.t()} | {:error, Changeset.t()}
  def delete_role(role, opts \\ []) do
    with :ok <- authorize(role.site, :delete_role, opts) do
      repo(role).delete(role)
    end
  end

  @doc """
  Lists all possible capabilities a Beacon role can have.
  """
  @spec list_capabilities() :: [:atom]
  def list_capabilities do
    [
      :create_layout,
      :update_layout,
      :publish_layout,
      :create_page,
      :update_page,
      :publish_page,
      :unpublish_page,
      :create_stylesheet,
      :update_stylesheet,
      :create_component,
      :update_component,
      :create_slot_for_component,
      :update_slot_for_component,
      :delete_slot_from_component,
      :create_slot_attr,
      :update_slot_attr,
      :delete_slot_attr,
      :create_snippet_helper,
      :create_error_page,
      :update_error_page,
      :delete_error_page,
      :create_event_handler,
      :update_event_handler,
      :delete_event_handler,
      :create_variant_for_page,
      :update_variant_for_page,
      :delete_variant_from_page,
      :create_live_data,
      :create_assign_for_live_data,
      :update_live_data_path,
      :update_live_data_assign,
      :delete_live_data,
      :delete_live_data_assign,
      :create_info_handler,
      :update_info_handler,
      :delete_info_handler,
      :create_role,
      :update_role,
      :delete_role
    ]
  end
end
