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

    * `actor_from_session/1` - a function which receives the user's session data, and returns some unique identifier for that user
    * `check_role/1` - a function which receives the identifier, and returns what role that user should have

  This allows you to integrate Beacon with any type of authentication system your app might require.

  ## Implementing the Beacon.Auth behaviour

  Let's take a look at the case where [`mix phx.gen.auth`](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html) was used to register and sign in users.

  The first question is "How does my app determine the access level (role) of a given user?".
  Some examples solutions might be:

    * Add a `role` column to the users table, and `:role` field on the User schema
    * Calculate the role dynamically based on other fields such as `admin?` or `registered_at`
    * Create a separate table to map each `user_id` to a `role`

  Regardless of which approach you choose, let's assume that logic is used in a function called
  `determine_role/1`.  Then we can create an auth module which implements `Beacon.Auth` behaviour:

  ```
  defmodule MyApp.Auth do
    @behaviour Beacon.Auth

    def actor_from_session(session) do
      Map.get(session, "user_token")
    end

    def check_role(user_token) do
      user_token
      |> MyApp.Accounts.get_user_by_session_token()
      |> determine_role()
    end

    defp determine_role(user) do
      ...
    end
  end
  ```

  In the above example, the `actor_from_session/1` function retrieves the `user_token` which is put
  into the session when a user logs in.

  Then `check_role/1` will receive that token, look up the user, and then determine the role of that user.

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

  alias Beacon.Auth.Role
  alias Beacon.Config
  alias Ecto.Changeset

  @doc """
  Parses the actor's identity from the session.
  """
  @callback actor_from_session(session :: map()) :: actor :: any()

  @doc """
  Checks the role of a given actor.

  Warning: this function should always check for the most recent data, in case it has changed.

  ```elixir
  # bad
  def check_role(actor), do: actor.role
  # good
  def check_role(actor), do: MyApp.Repo.one(from u in Users, where: u.id == ^actor, select: u.role)
  ```
  """
  @callback check_role(actor :: any()) :: role :: any()

  @doc """
  Check if an action is allowed.
  """
  @spec authorize(Site.t(), atom(), keyword()) :: :ok | {:error, :not_authorized}
  def authorize(site, action, opts) do
    if Keyword.get(opts, :auth, true) do
      do_authorize(site, opts[:actor], action)
    else
      :ok
    end
  end

  defp do_authorize(site, actor, action) do
    role = get_role(site, actor)

    query = from r in Role, where: r.site == ^site, where: r.name == ^to_string(role)

    with %{} = role <- repo(site).one(query),
         true <- to_string(action) in role.capabilities do
      :ok
    else
      _ -> {:error, :not_authorized}
    end
  end

  @doc """
  Uses a site's `:auth_module` from `Beacon.Config` to find the actor for a given session.
  """
  @spec get_actor(Site.t(), map()) :: any()
  def get_actor(site, session) do
    Config.fetch!(site).auth_module.actor_from_session(session)
  end

  defp get_role(site, actor) do
    Config.fetch!(site).auth_module.check_role(actor)
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
      :update_page,
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
