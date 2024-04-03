defmodule Beacon.Authorization.Policy do
  @moduledoc """
  Provides hooks into Beacon Authorization.

  ## Example

      defmodule MyApp.Beacon.AuthzPolicy do
        @behaviour Beacon.Authorization.Policy

        def get_agent(%{"session_id" => session_id}}) do
          MyApp.Identity.find_by_session_id!(session_id) # returns %{user_id: 1, role: :admin}
        end

        # admin has access to all operations
        def authorized?(%{role: :admin}, _, _), do: true

        # everyone can access page editor index
        def authorized?(_, :index, %{mod: :page_editor}), do: true

        # specific role can't delete a resource in page editor
        def authorized?(%{role: :fact_checker}, :delete, %{mod: :page_editor}), do: false
      end

  TODO: doc payload, possible operations, and context

  """

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
