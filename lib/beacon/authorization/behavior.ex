defmodule Beacon.Authorization.Behaviour do
  @moduledoc """
    Provides hooks into Beacon Authorization


    Currently, we are only protecting `Beacon.Pages.Page` and `Beacon.MediaLibrary.Asset` resources.

    ## Examples
    an example implmentation might look like:
    ```
    def get_agent(%{"session_id" => session_id}}) do
      Identity.find_by_session_id!(session_id)
    end
    ```

    ```
    def authorized?(_, :index, %Page{}), do: true

    def authorized?(%{role: :admin}, :new, %Page{}), do: true
    def authorized?(%{role: :editor}, :new, %Page{}), do: true
    def authorized?(%{role: :fact_checker}, :new, %Page{}), do: false

    def authorized?(%{role: :admin}, :edit, %Page{}), do: true
    def authorized?(%{role: :editor}, :edit, %Page{}), do: true
    def authorized?(%{role: :fact_checker}, :edit, %Page{}), do: true

    def authorized?(%{role: :admin}, :delete, %Page{}), do: true
    def authorized?(%{role: :editor}, :delete, %Page{}), do: false
    def authorized?(%{role: :fact_checker}, :delete, %Page{}), do: false

    def authorized?(%{role: :admin}, :index, %Asset{}), do: true
    def authorized?(%{role: :editor}, :index, %Asset{}), do: true
    def authorized?(%{role: :fact_checker}, :index, %Asset{}), do: false

    def authorized?(%{role: :admin}, :new, %Asset{}), do: true
    def authorized?(%{role: :editor}, :new, %Asset{}), do: true
    def authorized?(%{role: :fact_checker}, :new, %Asset{}), do: false

    def authorized?(%{role: :admin}, :upload, %Asset{}), do: true
    def authorized?(%{role: :editor}, :upload, %Asset{}), do: true
    def authorized?(%{role: :fact_checker}, :upload, %Asset{}), do: false
    ```
  """

  # returns agent
  @callback get_agent(payload :: any()) :: any()

  # operation, agent, context
  @callback authorized?(agent :: any(), operation :: atom(), context :: any()) :: boolean()
end
