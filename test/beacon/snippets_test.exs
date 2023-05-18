defmodule Beacon.SnippetsTest do
  use Beacon.DataCase

  import Beacon.Fixtures
  alias Beacon.Pages.Page
  alias Beacon.Snippets

  test "assigns" do
    assert Snippets.render(
             "page title is {{ page.title }}",
             %{page: %Page{title: "test"}}
           ) == {:ok, "page title is test"}

    assert Snippets.render(
             "author.id is {{ page.extra.author.id }}",
             %{page: %Page{extra: %{"author" => %{"id" => 1}}}}
           ) == {:ok, "author.id is 1"}
  end

  describe "helper" do
    defp start_loader(_) do
      start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
      :ok
    end

    defp create_snippet_helper(_) do
      helper =
        snippet_helper_fixture(
          site: "my_site",
          name: "author_name",
          body:
            String.trim(~S"""
            author_id = get_in(assigns, ["page", "extra", "author_id"])
            "test_#{author_id}"
            """)
        )

      Beacon.reload_site(:my_site)

      [helper: helper]
    end
  end

  setup [:start_loader, :create_snippet_helper]

  test "render" do
    assert Snippets.render(
             "author name is {% helper 'author_name' %}",
             %{page: %Page{site: "my_site", extra: %{"author_id" => 1}}}
           ) == {:ok, "author name is test_1"}
  end
end
