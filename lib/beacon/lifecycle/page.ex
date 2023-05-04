defmodule Beacon.Lifecycle.Page do
  import Beacon.Lifecycle

  @doc """
  Execute all steps for stage `:create_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec create_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def create_page(page) do
    steps = fetch_steps!(page.site, :create_page)
    execute_steps(:create_page, steps, page)
  end

  @doc """
  Execute all steps for stage `:update_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec update_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def update_page(page) do
    steps = fetch_steps!(page.site, :update_page)
    execute_steps(:update_page, steps, page)
  end

  @doc """
  Execute all steps for stage `:publish_page`.

  It's executed before the `page` is reloaded.
  """
  @spec publish_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def publish_page(page) do
    steps = fetch_steps!(page.site, :publish_page)
    execute_steps(:publish_page, steps, page)
  end
end
