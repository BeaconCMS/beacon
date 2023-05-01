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
