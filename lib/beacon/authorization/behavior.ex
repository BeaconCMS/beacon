defmodule Beacon.Authorization.Behaviour do
  @moduledoc """
    Provides hooks into Beacon Authorization

    ## Examples

  """

  # returns requestor_context
  @callback get_requestor_context(payload :: any()) :: any()

  # site, requestor_context, operation_context (needs type)
  @callback authorized?(Beacon.Type.Site.t(), requestor_context :: any(), operation_context :: map()) :: boolean()
  # requestor_context, operation_context (needs type)
  @callback authorized?(requestor_context :: any(), operation_context :: map()) :: boolean()
  # requestor_context
  @callback authorized_sites_for(requestor_context :: any()) :: list(Beacon.Type.Site.t())
  # site, requestor_context
  @callback authorized_for_site?(Beacon.Type.Site.t(), requestor_context :: any()) :: boolean()
end
