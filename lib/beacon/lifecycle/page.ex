defmodule Beacon.Lifecycle.Page do
  @moduledoc false

  alias Beacon.Content.Page
  alias Beacon.Lifecycle

  @behaviour Beacon.Lifecycle

  @impl Lifecycle
  def validate_output!(%Lifecycle{output: %Beacon.Content.Page{}} = lifecycle, _config, _sub_key), do: lifecycle

  def validate_output!(lifecycle, _config, _sub_key) do
    raise Beacon.LoaderError, """
    returned output for lifecycle #{lifecycle.name} must be of type Beacon.Content.Page

    Got:

      #{inspect(lifecycle.output)}

    """
  end

  @doc """
  Execute all steps for stage `:after_create_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec after_create_page(Page.t()) :: Page.t()
  def after_create_page(page) do
    Lifecycle.execute(__MODULE__, page.site, :after_create_page, page).output
  end

  @doc """
  Execute all steps for stage `:after_update_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec after_update_page(Page.t()) :: Page.t()
  def after_update_page(page) do
    Lifecycle.execute(__MODULE__, page.site, :after_update_page, page).output
  end

  @doc """
  Execute all steps for stage `:after_publish_page`.

  """
  @spec after_publish_page(Page.t()) :: Page.t()
  def after_publish_page(page) do
    Lifecycle.execute(__MODULE__, page.site, :after_publish_page, page).output
  end
end
