defmodule Beacon.Lifecycle.Page do
  @moduledoc false

  alias Beacon.Content.Page
  alias Beacon.Lifecycle

  @behaviour Beacon.Lifecycle

  @impl Lifecycle
  def validate_output!(%Lifecycle{output: %Beacon.Content.Page{}} = lifecycle, _config, _sub_key), do: lifecycle

  def validate_output!(lifecycle, _config, _sub_key) do
    raise Beacon.LoaderError, """
    return output for lifecycle #{lifecycle.name} must be of type Beacon.Content.Page

    Got:

      #{inspect(lifecycle.output)}

    """
  end

  @doc """
  Execute all steps for stage `:create_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec create_page(Page.t()) :: Page.t()
  def create_page(page) do
    lifecycle = Lifecycle.execute(__MODULE__, page.site, :create_page, page)
    lifecycle.output
  end

  @doc """
  Execute all steps for stage `:update_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec update_page(Page.t()) :: Page.t()
  def update_page(page) do
    lifecycle = Lifecycle.execute(__MODULE__, page.site, :update_page, page)
    lifecycle.output
  end

  @doc """
  Execute all steps for stage `:publish_page`.

  It's executed before the `page` is reloaded.
  """
  @spec publish_page(Page.t()) :: Page.t()
  def publish_page(page) do
    lifecycle = Lifecycle.execute(__MODULE__, page.site, :publish_page, page)
    lifecycle.output
  end
end
