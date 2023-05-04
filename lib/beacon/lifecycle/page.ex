defmodule Beacon.Lifecycle.Page do
  import Beacon.Lifecycle

  @doc """
  Execute all steps for stage `:create_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec create_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def create_page(page) do
    config = Beacon.Config.fetch!(page.site)
    do_create_page(page, Keyword.fetch!(config.lifecycle, :create_page))
  end

  @doc false
  def do_create_page(page, [] = _steps), do: page

  def do_create_page(page, steps) do
    execute_steps(:create_page, steps, page, nil)
  end

  @doc """
  Execute all steps for stage `:update_page`.

  It's executed in the same repo transaction, after the `page` record is saved into the database.
  """
  @spec update_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def update_page(page) do
    config = Beacon.Config.fetch!(page.site)
    do_update_page(page, Keyword.fetch!(config.lifecycle, :update_page))
  end

  @doc false
  def do_update_page(page, [] = _steps), do: page

  def do_update_page(page, steps) do
    execute_steps(:update_page, steps, page, nil)
  end

  @doc """
  Execute all steps for stage `:publish_page`.

  It's executed before the `page` is reloaded.
  """
  @spec publish_page(Beacon.Pages.Page.t()) :: Beacon.Pages.Page.t()
  def publish_page(page) do
    config = Beacon.Config.fetch!(page.site)
    do_publish_page(page, Keyword.fetch!(config.lifecycle, :publish_page))
  end

  @doc false
  def do_publish_page(page, [] = _steps), do: page

  def do_publish_page(page, steps) do
    execute_steps(:publish_page, steps, page, nil)
  end
end
