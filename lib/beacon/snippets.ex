defmodule Beacon.Snippets do
  @moduledoc """
  Snippets are small pieces of string with interpolated assigns.

  Think of it as small templates.

  ## Example

      iex> Beacon.Snippet.render("title is {{ page.title }}", %{page: %Page{title: "home"}})
      "title is home"

  Snippets use the [Liquid](https://shopify.github.io/liquid/) template under the hood,
  which means that all [filters](https://shopify.github.io/liquid/basics/introduction/#filters) are available for use.

  ## Example

      iex> Beacon.Snippet.render "{{ 'title' | capitalize }}"
      {:ok, "Title"}

  Helper functions can be created and called to perform operations on the provided assigns:

      iex> page = Beacon.Pages.create_page(%{site: "my_site", extra: %{"author_id": 1}})
      iex> Beacon.Snippet.create_helper(%{site: "my_site", name: "author_name", body: ~S\"""
      ...> author_id = get_in(assigns, ["page", "extra", "author_id"])
      ...> MyApp.fetch_author_name(author_id)
      ...> \"""
      iex> Beacon.Snippet.render("Author is {{ helper 'author_name' }}", %{page: page})
      {:ok, "Author is Anon"}

  They can be used in some places:

    * Meta Tag value
    * Page Schema (structured Schema.org tags)

  """

  import Ecto.Query
  alias Beacon.Repo
  alias Beacon.Snippets.Helper
  alias Beacon.Snippets.Parser

  @doc """

  """
  def create_helper(attrs) do
    %Helper{}
    |> Ecto.Changeset.cast(attrs, [:site, :name, :body])
    |> Ecto.Changeset.validate_required([:site, :name, :body])
    |> Ecto.Changeset.unique_constraint([:site, :name])
    |> Repo.insert()
  end

  def create_helper!(attrs) do
    case create_helper(attrs) do
      {:ok, helper} -> helper
      {:error, changeset} -> raise "failed to create snippet helper #{inspect(changeset.errors)} "
    end
  end

  def list_helpers_for_site(site) do
    Repo.all(from h in Helper, where: h.site == ^site)
  end

  @doc """
  Render a `snippet` template.

  See `render/2` for passing assigns to templates.
  """
  def render(snippet) when is_binary(snippet) do
    with {:ok, template} <- Solid.parse(snippet, parser: Parser),
         {:ok, template} <- Solid.render(template, %{}) do
      {:ok, to_string(template)}
    else
      error -> error
    end
  end

  @doc """
  Render `snippet` with the given `assigns`.

  Allowed assigns:

    * :page (Beacon.Pages.Page.t())

  """
  def render(snippet, assigns) when is_binary(snippet) and is_map(assigns) do
    page =
      assigns.page
      |> Map.from_struct()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    assigns = %{"page" => page}

    with {:ok, template} <- Solid.parse(snippet, parser: Parser),
         {:ok, template} <- Solid.render(template, assigns) do
      {:ok, to_string(template)}
    else
      # TODO: errors
      {:error, error} -> raise error
      _ -> raise Beacon.LoaderError
    end
  end
end
