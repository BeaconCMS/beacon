defmodule Beacon.Authorization.PassThrough do
  @behaviour Beacon.Authorization.Behaviour

  @impl true
  def get_requestor_context(data), do: data

  @impl true
  def authorized?(_requestor_context, _operation_context), do: true

  @impl true
  def authorized?(_site, _requestor_context, _operation_context), do: true
end
