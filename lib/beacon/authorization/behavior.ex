defmodule Beacon.Authorization.Behaviour do
  @moduledoc """
  Provides hooks into Beacon Authorization.

  Currently, we are only protecting `Beacon.Pages.Page` and `Beacon.MediaLibrary.Asset` resources.

  ## Example

      def get_agent(%{"session_id" => session_id}}) do
        MyApp.Identity.find_by_session_id!(session_id)
      end

      def authorized?(_, :index, %Page{}), do: true
      def authorized?(%{role: :admin}, :new, %Page{}), do: true
      def authorized?(%{role: :fact_checker}, :new, %Page{}), do: false
      def authorized?(%{role: :admin}, :upload, %Asset{}), do: true
      def authorized?(_, :upload, %Asset{}), do: false
  """

  @doc """
  Return the agent assigned by `BeaconWeb.Admin.Hooks.AssignAgent`
  """
  @callback get_agent(payload :: any()) :: any()

  @doc """
  Return `true` to authorize `agent` to perform `operation` in the given `context`,
  otherwise return `false` to block such operation.

  Note that Admin will either redirect or display a flash message
  if the operation is not authorized.
  """
  @callback authorized?(agent :: any(), operation :: atom(), context :: map() | struct() | nil) :: boolean()
end
