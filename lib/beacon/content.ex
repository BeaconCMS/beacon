defmodule Beacon.Content do
  @moduledoc """
  Manage content for sites.

  TODO
  """

  import Ecto.Query
  alias Beacon.Repo
  alias Beacon.Layouts.Layout
  alias Beacon.Pages.Page
  alias Beacon.Types.Site

  @doc """
  TODO
  """
  @spec list_layouts(Site.t()) :: [Layout.t()]
  def list_layouts(site) do
    Repo.all(from l in Layout, where: l.site == ^site)
  end

  @doc """
  TODO
  """
  @spec change_page(Page.t(), map()) :: Ecto.Changeset.t()
  def change_page(%Page{} = page, attrs \\ %{}) do
    Page.changeset(page, attrs)
  end

  @doc """
  TODO
  """
  @spec validate_page(Site.t(), Page.t(), map()) :: Ecto.Changeset.t()
  def validate_page(site, %Page{} = page, params) when is_atom(site) and is_map(params) do
    {extra_params, page_params} = Map.pop(params, "extra")

    page
    |> change_page(page_params)
    |> Map.put(:action, :validate)
    |> Beacon.PageField.apply_changesets(site, extra_params)
  end

  @doc """
  TODO
  """
  @spec list_pages(Site.t(), String.t()) :: [Page.t()]
  def list_pages(site, search_query, opts \\ [])

  def list_pages(site, search_query, opts) when is_atom(site) and is_binary(search_query) do
    per_page = Keyword.get(opts, :per_page, 20)

    Repo.all(
      from p in Page,
        where: p.site == ^site,
        where: ilike(p.path, ^"%#{search_query}%") or ilike(p.title, ^"%#{search_query}%"),
        limit: ^per_page,
        order_by: [asc: p.order, asc: p.path]
    )
  end

  def list_pages(site, _search_query, opts) when is_atom(site) do
    per_page = Keyword.get(opts, :per_page, 20)

    Repo.all(
      from p in Page,
        where: p.site == ^site,
        limit: ^per_page,
        order_by: [asc: p.order, asc: p.path]
    )
  end

  @doc """
  TODO
  """
  @spec create_page(map()) :: {:ok, Page.t()} | {:error, Ecto.Changeset.t()}
  def create_page(attrs) when is_map(attrs) do
    ch = %Page{} |> Page.changeset(attrs)
    IO.inspect(ch)

    ch |> Repo.insert()
  end
end
