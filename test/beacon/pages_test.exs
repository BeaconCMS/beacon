defmodule Beacon.PagesTest do
  use Beacon.DataCase

  import Beacon.Fixtures
  alias Beacon.Pages
  alias Beacon.Pages.Page

  defp create_page(_) do
    page_fixture()
    :ok
  end

  describe "list_pages/1" do
    setup [:create_page]

    test "list pages" do
      assert [%Page{}] = Pages.list_pages()
    end
  end

  describe "create_page/1" do
    test "includes default meta tags" do
      attrs = %{
        path: "home",
        site: "my_site",
        layout_id: layout_fixture().id,
        template: """
        <main>
          <h1>my_site#home</h1>
        </main>
        """,
        format: :heex,
        skip_reload: true
      }

      assert {:ok, page} = Pages.create_page(attrs)
      assert page.meta_tags == [%{"name" => "foo_meta_tag"}, %{"name" => "bar_meta_tag"}, %{"name" => "baz_meta_tag"}]
    end
  end

  test "list_pages_for_site order" do
    page_fixture(path: "", order: 0)
    page_fixture(path: "blog_a", order: 0)
    page_fixture(path: "blog_b", order: 1)

    assert [%{path: ""}, %{path: "blog_a"}, %{path: "blog_b"}] = Pages.list_pages_for_site(:my_site, [:events, :helpers])
  end

  describe "extra" do
    test "update existing field" do
      page = page_fixture(extra: %{})

      assert {:ok, %Page{extra: %{"tags" => "foo,bar"}}} = Pages.update_page(page, %{"extra" => %{"tags" => "foo,bar"}})
    end

    test "skip non-existing field" do
      page = page_fixture(extra: %{})

      assert {:ok, %Page{extra: %{}}} = Pages.update_page(page, %{"extra" => %{"foo" => "bar"}})
    end
  end
end
