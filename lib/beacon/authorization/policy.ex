defmodule Beacon.Authorization.Policy do
  @moduledoc false

  # TODO: review authz
  # """
  # Rules to authorize agents to perform operations in Beacon.

  # Below is an example of a policy that finds the person performing the operation through a session_id
  # returned in the login and checks if the person is authorized to perform some operations.

  # ## Example

  #     defmodule MyApp.Beacon.AuthzPolicy do
  #       @behaviour Beacon.Authorization.Policy

  #       def get_agent(%{"session_id" => session_id}) do
  #         MyApp.Identity.find_by_session_id!(session_id) # returns %{user_id: 1, role: :admin}
  #       end

  #       # admin has access to all operations
  #       def authorized?(%{role: :admin}, _, _), do: true

  #       # everyone can access page editor index (list pages)
  #       def authorized?(_, :index, %{mod: :page_editor}), do: true

  #       # role external_contributor can't delete pages
  #       def authorized?(%{role: :external_contributor}, :delete, %{mod: :page_editor}), do: false
  #     end
  # """

  # TODO: doc payload, possible operations, and context

  @doc """
  Return the agent assigned by `Beacon.LiveAdmin.Hooks.AssignAgent`
  """
  @callback get_agent(payload :: any()) :: any()

  @doc """
  Return `true` to authorize `agent` to perform `operation` in the given `context`,
  otherwise return `false` to block such operation.

  Note that Beacon LiveAdmin will either redirect or display a flash message
  if the operation is not authorized.
  """
  @callback authorized?(agent :: any(), operation :: atom(), context :: map()) :: boolean()
end
